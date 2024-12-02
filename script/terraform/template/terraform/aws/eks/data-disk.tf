#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  ebs_device_names = [
    "/dev/xvdh",
    "/dev/xvdi",
    "/dev/xvdj",
    "/dev/xvdk",
    "/dev/xvdl",
    "/dev/xvdm",
    "/dev/xvdn",
    "/dev/xvdo",
    "/dev/xvdp",
    "/dev/xvdq",
    "/dev/xvdr",
    "/dev/xvds",
    "/dev/xvdt",
    "/dev/xvdu",
    "/dev/xvdv",
    "/dev/xvdw",
    "/dev/xvdx",
    "/dev/xvdy",
    "/dev/xvdz",
  ]
  isv_device_names = concat([
    "/dev/xvdb",
    "/dev/xvdc",
    "/dev/xvdd",
    "/dev/xvde",
    "/dev/xvdf",
    "/dev/xvdg",
  ], local.ebs_device_names)
}

locals {
  ebs_disks_flat = flatten([
    for k,v in local.instances : [
      for i in range(v.data_disk_spec!=null?(v.data_disk_spec.disk_type!="local"?v.data_disk_spec.disk_count:0):0) : {
        name = "vm-${k}-ebs-disk-${i}"
        instance = k
        disk_size = v.data_disk_spec.disk_size
        disk_type = v.data_disk_spec.disk_type
        disk_iops = v.data_disk_spec.disk_iops
        disk_throughput = v.data_disk_spec.disk_throughput
        lun       = i
      }
    ]
  ])
  ebs_disks = {
    for dsk in local.ebs_disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_type = dsk.disk_type
      disk_iops = dsk.disk_iops
      disk_throughput = dsk.disk_throughput
      lun       = dsk.lun
    }
  }
}

locals {
  isv_disks = {
    for k,v in local.instances : k => [
      for i in range(v.data_disk_spec!=null?(v.data_disk_spec.disk_type=="local"?v.data_disk_spec.disk_count:0):0) : {
        device_name  = local.isv_device_names[i]
        virtual_name = "ephemeral${i}"
        lun          = i
      }
    ]
  }
}

resource "aws_ebs_volume" "default" {
  for_each = local.ebs_disks

  availability_zone = var.zones[0]
  iops = each.value.disk_iops
  throughput = each.value.disk_throughput
  size = each.value.disk_size
  type = each.value.disk_type
}

resource "aws_volume_attachment" "default" {
  for_each    = local.ebs_disks
  volume_id   = aws_ebs_volume.default[each.key].id
  instance_id = data.aws_instance.default[each.value.instance].id
  device_name = local.ebs_device_names[each.value.lun]
}

data "template_cloudinit_config" "default" {
  for_each = local.instances
  gzip = false
  base64_encode = true

  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/init-disks.sh.tpl", {
      disks = concat([ 
        for k,v in local.ebs_disks : {
          serial = replace(aws_ebs_volume.default[k].id, "-", "")
          device = local.ebs_device_names[v.lun] 
          mount_path = "/mnt/disk${v.lun+1}"
          user   = local.os_image_user[local.instances[v.instance].os_type]
          group  = local.os_image_user[local.instances[v.instance].os_type]
        } if v.instance == each.key
      ], [
        for v in local.isv_disks[each.key] : {
          serial = ""
          device = v.device_name
          mount_path = "/mnt/disk${v.lun+1}"
          user   = local.os_image_user[local.instances[each.key].os_type]
          group  = local.os_image_user[local.instances[each.key].os_type]
        }
      ])
      disk_format = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_format:"ext4"
    })
  }

  part {
    filename = "run-eks"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/init-eks.sh.tpl", {
      cluster_name = aws_eks_cluster.default.name
      certificate_data = aws_eks_cluster.default.certificate_authority[0].data
      cluster_endpoint = aws_eks_cluster.default.endpoint
      dns_cluster_ip = format("%s.10", replace(var.service_network_cidr, "/(.*)[.].*/", "$1"))
    })
  }
}

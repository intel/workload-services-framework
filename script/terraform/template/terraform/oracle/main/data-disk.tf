#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  ebs_device_names = [
    "/dev/oracleoci/oraclevdh",
    "/dev/oracleoci/oraclevdi",
    "/dev/oracleoci/oraclevdj",
    "/dev/oracleoci/oraclevdk",
    "/dev/oracleoci/oraclevdl",
    "/dev/oracleoci/oraclevdm",
    "/dev/oracleoci/oraclevdn",
    "/dev/oracleoci/oraclevdo",
    "/dev/oracleoci/oraclevdp",
    "/dev/oracleoci/oraclevdq",
    "/dev/oracleoci/oraclevdr",
    "/dev/oracleoci/oraclevds",
    "/dev/oracleoci/oraclevdt",
    "/dev/oracleoci/oraclevdu",
    "/dev/oracleoci/oraclevdv",
    "/dev/oracleoci/oraclevdw",
    "/dev/oracleoci/oraclevdx",
    "/dev/oracleoci/oraclevdy",
    "/dev/oracleoci/oraclevdz",
  ]
  isv_device_names = concat([
    "/dev/oracleoci/oraclevdb",
    "/dev/oracleoci/oraclevdc",
    "/dev/oracleoci/oraclevdd",
    "/dev/oracleoci/oraclevde",
    "/dev/oracleoci/oraclevdf",
    "/dev/oracleoci/oraclevdg",
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
        disk_performance = v.data_disk_spec.disk_performance
        lun       = i
      }
    ]
  ])
  ebs_disks = {
    for dsk in local.ebs_disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_type = dsk.disk_type
      disk_performance = dsk.disk_performance
      lun       = dsk.lun
    }
  }
}

locals {
  isv_disks = {
    for k,v in local.instances : k => [
      for i in range(v.data_disk_spec!=null?(v.data_disk_spec.disk_type=="local"?v.data_disk_spec.disk_count:0):0) : {
        device_name  = local.isv_device_names[i]
        lun          = i
      }
    ]
  }
}

resource "oci_core_volume" "default" {
  for_each = local.ebs_disks

  display_name = "wsf-${var.job_id}-${each.key}"
  availability_domain = var.zone
  compartment_id = var.compartment

  size_in_gbs = each.value.disk_size
  vpus_per_gb = each.value.disk_performance!=null?parseint(each.value.disk_performance,10):null
  
  freeform_tags = merge(var.common_tags, {
    Name = "wsf-${var.job_id}-${each.key}"
  })
}

resource "oci_core_volume_attachment" "default" {
  for_each    = local.ebs_disks

  display_name = "wsf-${var.job_id}-${each.key}-attachment"
  instance_id = oci_core_instance.default[each.value.instance].id

  attachment_type = "iscsi"
  device = local.ebs_device_names[each.value.lun]
  volume_id = oci_core_volume.default[each.key].id
}

data "template_cloudinit_config" "default" {
  for_each = local.instances
  gzip = false
  base64_encode = true
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/init-disks.sh", {
      disks = concat([ 
        for k,v in local.ebs_disks : {
          device = local.ebs_device_names[v.lun] 
          mount_path = "/mnt/disk${v.lun+1}"
          user   = local.os_image_user[local.instances[v.instance].os_type]
          group  = local.os_image_user[local.instances[v.instance].os_type]
        } if v.instance == each.key
      ], [
        for v in local.isv_disks[each.key] : {
          device = v.device_name
          mount_path = "/mnt/disk${v.lun+1}"
          user   = local.os_image_user[local.instances[each.key].os_type]
          group  = local.os_image_user[local.instances[each.key].os_type]
        }
      ])
      disk_format = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_format:"ext4"
    })
  }
}

resource "null_resource" "init-iscsi" {
  for_each = {
    for k,v in local.instances : k => v
      if (v.data_disk_spec!=null?(v.data_disk_spec.disk_type!="local"?v.data_disk_spec.disk_count:0):0) > 0
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/templates/init-iscsi.sh", {
      ssh_access_key = var.ssh_private_key_file
      user  = local.os_image_user[each.value.os_type]
      host  = oci_core_instance.default[each.key].public_ip
      disks = [
        for k,v in local.ebs_disks : {
          iqn   = oci_core_volume_attachment.default[k].iqn
          ip    = oci_core_volume_attachment.default[k].ipv4
          port  = oci_core_volume_attachment.default[k].port
        } if v.instance == each.key
      ]
    })
  }
}


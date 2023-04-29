
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

  availability_zone = var.zone
  iops = each.value.disk_iops
  throughput = each.value.disk_throughput
  size = each.value.disk_size
  type = each.value.disk_type
  
  tags = {
    Name = "wsf-${var.job_id}-disk-${each.key}"
  }
}

resource "aws_volume_attachment" "default" {
  for_each    = local.ebs_disks
  volume_id   = aws_ebs_volume.default[each.key].id
  instance_id = var.spot_instance?aws_spot_instance_request.default[each.value.instance].spot_instance_id:aws_instance.default[each.value.instance].id
  device_name = local.ebs_device_names[each.value.lun]
}

data "template_cloudinit_config" "default" {
  for_each = local.instances
  gzip = false
  base64_encode = true
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("./template/terraform/aws/main/cloud-init.sh", {
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
}

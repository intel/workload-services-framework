#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
data "template_file" "windows" {
  for_each = { for k,v in local.instances : k=>v if local.is_windows[k] }

  template = file("${path.module}/templates/ec2launchv2.yaml")
  vars = {
    winrm_port = var.winrm_port
    drive_count = length(split(" ",join(" ", concat([
      for k,v in local.ebs_disks : local.ebs_device_names[v.lun] if v.instance == each.key
    ], [
      for v in local.isv_disks[each.key] : v.device_name
    ]))))
    disks = join(" ", concat([
      for k,v in local.ebs_disks : local.ebs_device_names[v.lun] if v.instance == each.key
    ], [
      for v in local.isv_disks[each.key] : v.device_name
    ]))
  }
}

data "template_cloudinit_config" "linux" {
  for_each = {
    for k,v in local.instances: k=>v if !local.is_windows[k]
  }
  gzip = false
  base64_encode = true
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/cloud-init.sh", {
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



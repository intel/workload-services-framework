#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
locals {
  drive_letters = [
    "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
  ]
}

# data "template_file" "windows" {

#   template = file("${path.module}/templates/init.ps1")
#   vars = {
#     winrm_port     = 5986
#     drive_count    = 2
#   }
# }

data "template_file" "windows" {
  for_each =  local.instances

  template = file("${path.module}/templates/init.ps1")
  vars = {
    winrm_port  = 5986
    drive_count = length(split(" ",join(" ", concat([
      for k,v in local.ebs_disks : local.ebs_device_names[v.lun] if v.instance == each.key
    ], [
      for v in local.isv_disks[each.key] : v.device_name
    ]))))
  }
}


# data "template_cloudinit_config" "default" {
#   for_each = local.instances
#   gzip = false
#   base64_encode = true
#   part {
#     filename     = "init.cfg"
#     content_type = "text/x-shellscript"
#     content      = data.template_file.windows.rendered
#   }
# }
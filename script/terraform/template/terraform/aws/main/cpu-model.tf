#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "external" "cpu_model" {
  for_each = {
    for k,v in local.instances : k => v
      if v.cpu_model_regex != null
  }

  program = fileexists("${path.root}/cleanup.logs")?[
    "printf",
    "{\"cpu_model\":\":\"}"
  ]:local.is_windows[each.key]?[
    "timeout",
    var.cpu_model_timeout,
    "${path.module}/templates/get-cpu-model.py"
  ]:[ 
    "timeout", 
    var.cpu_model_timeout,
    "${path.module}/templates/get-cpu-model.sh", 
    "-i", 
    "${path.root}/${var.ssh_pri_key_file}", 
    "${local.os_image_user[each.value.os_type]}@${var.spot_instance?aws_spot_instance_request.default[each.key].public_ip:aws_instance.default[each.key].public_ip}" 
  ]

  query = local.is_windows[each.key]?{
    host = var.spot_instance?aws_spot_instance_request.default[each.key].public_ip:aws_instance.default[each.key].public_ip
    port = var.winrm_port
    user = local.os_image_user[each.value.os_type]
    secret = rsadecrypt(var.spot_instance?aws_spot_instance_request.default[each.key].password_data:aws_instance.default[each.key].password_data,file(var.ssh_pri_key_file))
  }:{}
}


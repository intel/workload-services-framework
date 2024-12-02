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
  ]:[ 
    "timeout", 
    var.cpu_model_timeout,
    "${path.module}/templates/get-cpu-model.sh", 
    "-i", 
    "${path.root}/${var.ssh_private_key_file}", 
    "${local.os_image_user[each.value.os_type]}@${oci_core_instance.default[each.key].public_ip}" 
  ]
}


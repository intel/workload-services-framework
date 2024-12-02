#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "external" "cpu_model" {
  for_each = {
    for k,v in local.vms : k => v
      if v.cpu_model_regex != null
  }

  program = fileexists("${path.root}/cleanup.logs")?[
    "printf",
    "{\"cpu_model\":\":\"}"
  ]:contains(keys(azurerm_linux_virtual_machine.default), each.key)?[
    "timeout",
    var.cpu_model_timeout,
    "${path.module}/templates/get-cpu-model.sh", 
    "-i", 
    "${path.root}/${var.ssh_pri_key_file}", 
    "${local.os_image_user[each.value.os_type]}@${azurerm_public_ip.default[each.key].ip_address}" 
  ]:[
    "timeout",
    var.cpu_model_timeout,
    "${path.module}/templates/get-cpu-model.py",
  ]

  query = contains(keys(azurerm_windows_virtual_machine.default), each.key)?{
    host = azurerm_public_ip.default[each.key].ip_address
    port = var.winrm_port
    user = local.os_image_user[each.value.os_type]
    secret = random_password.default.0.result
  }:{}

  depends_on = [
    azurerm_virtual_machine_extension.setup
  ]
}


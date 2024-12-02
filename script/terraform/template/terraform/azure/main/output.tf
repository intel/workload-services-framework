#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  winrm_common = {
    ansible_connection = "winrm"
    ansible_connection: "winrm",
    ansible_winrm_server_cert_validation: "ignore",
    ansible_winrm_transport: "basic",
    ansible_winrm_scheme: "https",
    ansible_winrm_connection_timeout: var.winrm_timeout,
  }
}

output "instances" {
  value = {
    for k,v in local.vms : k => merge(contains(keys(azurerm_windows_virtual_machine.default),k)?local.winrm_common:{}, {
      public_ip = var.allocate_public_ip?azurerm_public_ip.default[k].ip_address:azurerm_network_interface.default[k].private_ip_address
      private_ip = azurerm_network_interface.default[k].private_ip_address
      instance_type = v.instance_type
      user_name = local.os_image_user[v.os_type]
    }, {
      for k1,v1 in azurerm_windows_virtual_machine.default : "ansible_password" => random_password.default.0.result if k1 == k
    }, {
      for k1,v1 in azurerm_windows_virtual_machine.default : "ansible_port" => var.winrm_port if k1 == k
    })
  }
}

output "terraform_replace" {
  value = {
    command = join(" ",[
      for k,v in local.vms :
        contains(keys(azurerm_linux_virtual_machine.default),k)?"-replace=azurerm_linux_virtual_machine.default[${k}]":"-replace=azurerm_windows_virtual_machine.default[${k}]"
        if (v.cpu_model_regex!=null&&v.cpu_model_regex!="")?replace(data.external.cpu_model[k].result.cpu_model,v.cpu_model_regex,"")==data.external.cpu_model[k].result.cpu_model:false
    ])
    cpu_model = {
      for k,v in local.vms :
        k => data.external.cpu_model[k].result.cpu_model
        if v.cpu_model_regex!=null
    }
  }
}


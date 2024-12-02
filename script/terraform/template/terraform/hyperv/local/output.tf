#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  winrm_common = {
    ansible_connection: "winrm",
    ansible_winrm_server_cert_validation: "ignore",
    ansible_winrm_transport: "basic",
    ansible_winrm_scheme: "https",
    ansible_winrm_connection_timeout: var.winrm_timeout,
    ansible_winrm_proxy: null,
  }
}

output "instances" {
  value = merge({
    for k,v in local.instances : k => merge(local.is_windows[k]?local.winrm_common:{
      ssh_port: var.ssh_port,
    }, {
      public_ip: data.external.ip[k].result.ip,
      private_ip: data.external.ip[k].result.ip,
      user_name: local.os[local.instances[k].os_type].user
      instance_type: "c${local.instances[k].cpu_core_count}m${local.instances[k].memory_size}"
      vmhost_host: "hpvhost-0",
    }, {
      for k1,v1 in random_password.default : "ansible_password" => v1.result
        if (k==k1) && local.is_windows[k1]
    }, {
      for k1,v1 in random_password.default : "ansible_port" => var.winrm_port
        if (k==k1) && local.is_windows[k1]
    })
  }, {
    "hpvhost-0": merge(local.winrm_common, {
      public_ip: var.hpv_host.host,
      private_ip: var.hpv_host.host,
      user_name: local.configs.winrm_user,
      ansible_port: var.hpv_host.port,
      ansible_password: "",
      vm_group: "vmhost_hosts",
    })
  })
}

output "options" {
  value = {
    sut_update_datetime = true
  }
}


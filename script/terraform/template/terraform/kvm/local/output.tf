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
  value = merge({
    for k,v in libvirt_domain.default : k => merge(local.is_windows[k]?local.winrm_common:{}, {
      public_ip: local.is_windows[k]?"127.0.0.1":data.external.ip[k].result.ip,
      private_ip: data.external.ip[k].result.ip,
      user_name: local.os[local.instances[k].os_type].user,
      instance_type: "c${v.vcpu}m${v.memory/1024}",
      vmhost_host: "kvmhost-${var.kvm_index}",
    }, {
      for k1,v1 in random_password.default : "ansible_password" => v1.result
        if (k==k1) && local.is_windows[k1]
    }, {
      for k1,v1 in random_password.default : "ansible_port" => local.winrm_lports[k1]
        if (k==k1) && local.is_windows[k1]
    })
  }, length(local.instances)>0?{
    "kvmhost-${var.kvm_index}": {
      public_ip: var.kvm_host.host,
      private_ip: var.kvm_host.host,
      ansible_ssh_private_key_file: var.ssh_pri_key_file,
      user_name: var.kvm_host.user,
      vm_group: "vmhost_hosts",
    }
  }:{})
}

output "options" {
  value = {
    sut_update_datetime: true,
  }
}


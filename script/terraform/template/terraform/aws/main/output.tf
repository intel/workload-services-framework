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
    for k,v in var.spot_instance?aws_spot_instance_request.default:aws_instance.default : k => merge({
      public_ip = v.public_ip
      private_ip = v.private_ip
      user_name = local.os_image_user[local.instances[k].os_type]
      instance_type = v.instance_type
    }, local.is_windows[k]?merge(local.winrm_common, {
      ansible_password = rsadecrypt(v.password_data,file(var.ssh_pri_key_file))
      ansible_port = var.winrm_port
    }):{})
  }
}

output "terraform_replace" {
  value = {
    command = join(" ",[
      for k,v in local.instances :
        var.spot_instance?"-replace=aws_spot_instance_request.default[${k}]":"-replace=aws_instance.default[${k}]"
        if (v.cpu_model_regex!=null&&v.cpu_model_regex!="")?replace(data.external.cpu_model[k].result.cpu_model,v.cpu_model_regex,"")==data.external.cpu_model[k].result.cpu_model:false
    ])
    cpu_model = {
      for k,v in local.instances : 
        k => data.external.cpu_model[k].result.cpu_model
        if v.cpu_model_regex!=null
    }
  }
}

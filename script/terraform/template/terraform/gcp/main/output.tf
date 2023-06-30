#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "instances" {
  value = {
    for i, instance in google_compute_instance.default : i => {
        public_ip: instance.network_interface.0.access_config.0.nat_ip,
        private_ip: instance.network_interface.0.network_ip,
        user_name: local.os_image_user[local.vms[i].os_type],
        instance_type: instance.machine_type,
    }
  }
}

output "terraform_replace" {
  value = {
    command = join(" ",[
      for k,v in local.vms :
        "-replace=google_compute_instance.default[${k}]"
        if v.cpu_model_regex!=null?(replace(data.external.cpu_model[k].result.cpu_model,startswith(v.cpu_model_regex,"/")?v.cpu_model_regex:"/^.*${v.cpu_model_regex}.*$/", "")!=""):false
    ])
    cpu_model = {
      for k,v in local.vms :
        k => data.external.cpu_model[k].result.cpu_model
        if v.cpu_model_regex!=null
    }
  }
}

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "instances" {
  value = {
    for k,v in oci_core_instance.default : k => {
        public_ip: v.public_ip,
        private_ip: v.private_ip,
        user_name: local.os_image_user[local.instances[k].os_type]
        instance_type: v.shape,
    }
  }
}

output "terraform_replace" {
  value = {
    command = join(" ",[
      for k,v in local.instances :
        "-replace=oci_core_instance.default[${k}]"
        if (v.cpu_model_regex!=null&&v.cpu_model_regex!="")?replace(data.external.cpu_model[k].result.cpu_model,v.cpu_model_regex,"")==data.external.cpu_model[k].result.cpu_model:false
    ])
    cpu_model = {
      for k,v in local.instances :
        k => data.external.cpu_model[k].result.cpu_model
        if v.cpu_model_regex!=null
    }
  }
}


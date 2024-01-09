#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "instances" {
  value = {
    for i, instance in tencentcloud_instance.default : i => {
        public_ip: instance.public_ip,
        private_ip: instance.private_ip,
        user_name: local.os_user_name[local.instances[i].os_type]
        instance_type: instance.instance_type,
    }
  }
}

output "terraform_replace" {
  value = {
    command = join(" ",[
      for k,v in local.instances :
        "-replace=tencentcloud_instance.default[${k}]"
        if (v.cpu_model_regex!=null&&v.cpu_model_regex!="")?replace(data.external.cpu_model[k].result.cpu_model,v.cpu_model_regex,"")==data.external.cpu_model[k].result.cpu_model:false
    ])
    cpu_model = {
      for k,v in local.instances :
        k => data.external.cpu_model[k].result.cpu_model
        if v.cpu_model_regex!=null
    }
  }
}

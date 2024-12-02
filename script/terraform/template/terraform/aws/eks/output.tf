#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

output "instances" {
  value = {
    for k,v in data.aws_instance.default : k => {
        public_ip = v.public_ip
        private_ip = v.private_ip
        user_name = local.os_image_user[local.instances[k].os_type]
        instance_type = v.instance_type
    }
  }
}

output "options" {
  value = {
    k8s_enable_registry = true
    k8s_enable_csp_registry = true
    k8s_remote_registry_url = aws_ecr_repository.default.repository_url
    skopeo_sut_accessible_registries = aws_ecr_repository.default.repository_url
  }
}

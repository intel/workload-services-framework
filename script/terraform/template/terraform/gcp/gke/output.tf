#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "instances" {
  value = {
    for k,v in data.google_compute_instance.default : k => {
      public_ip: v.network_interface.0.access_config.0.nat_ip,
      private_ip: v.network_interface.0.network_ip,
      user_name: local.os_image_user[local.vms[k].os_type],
      instance_type: v.machine_type,
    }
  }
}

output "options" {
  value = {
    k8s_enable_registry = true
    k8s_enable_csp_registry = true
    k8s_remote_registry_url = local.repository_url
    skopeo_sut_accessible_registries = local.repository_url
  }
}

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
locals {
  instances_flat = flatten([
    for profile in var.instance_profiles : [
      for i in range(profile.vm_count): {
        index = i
        profile = profile.name
        cpu_core_count = profile.cpu_core_count
        memory_size = profile.memory_size
        os_image = profile.os_image
        os_type = profile.os_type
        os_disk_size = profile.os_disk_size
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
        network_spec = profile.network_spec!=null?profile.network_spec[i]:null
      }
    ]
  ])
}

locals {
  instances = {
    for vm in local.instances_flat : "${vm.profile}-${vm.index}" => {
      cpu_core_count = vm.cpu_core_count
      memory_size = vm.memory_size
      profile = vm.profile
      os_image = vm.os_image
      os_type = vm.os_type
      os_disk_size = vm.os_disk_size
      data_disk_spec = vm.data_disk_spec
      network_spec = vm.network_spec
    }
  }
}


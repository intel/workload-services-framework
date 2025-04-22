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
        instance_type = profile.instance_type
        cpu_model_regex = profile.cpu_model_regex
        accelerators = profile.accelerators
        os_image = profile.os_image
        os_type = profile.os_type
        os_disk_type = profile.os_disk_type
        os_disk_size = profile.os_disk_size
        os_disk_performance = profile.os_disk_performance
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
      }
    ]
  ])
}

locals {
  instances = {
    for vm in local.instances_flat : "${vm.profile}-${vm.index}" => {
      instance_type = vm.instance_type
      cpu_model_regex = vm.cpu_model_regex
      accelerators = vm.accelerators
      os_image = vm.os_image
      profile = vm.profile
      os_type = vm.os_type
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      os_disk_performance = vm.os_disk_performance
      data_disk_spec = vm.data_disk_spec
    }
  }
}


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
        cpu_core_count = profile.cpu_core_count
        threads_per_core = profile.threads_per_core
        os_image = profile.os_image
        os_type = profile.os_type
        os_disk_type = profile.os_disk_type
        os_disk_size = profile.os_disk_size
        os_disk_iops = profile.os_disk_iops
        os_disk_throughput = profile.os_disk_throughput
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
        network_spec = profile.network_spec!=null?profile.network_spec[i]:null
      }
    ]
  ])
}

locals {
  instances = {
    for vm in local.instances_flat : "${vm.profile}-${vm.index}" => {
      instance_type = vm.instance_type
      cpu_core_count = vm.cpu_core_count
      threads_per_core = vm.threads_per_core
      os_image = vm.os_image
      profile = vm.profile
      os_type = vm.os_type
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      os_disk_iops = vm.os_disk_iops
      os_disk_throughput = vm.os_disk_throughput
      data_disk_spec = vm.data_disk_spec
      network_spec = vm.network_spec
    }
  }
}

locals {
  spot_instances = {
    for k,v in local.instances : k => v if var.spot_instance
  }

  ondemand_instances = {
    for k,v in local.instances : k => v if !var.spot_instance
  }
}

locals {
  profile_map = {
    for profile in var.instance_profiles: profile.name => profile
  }
}

locals {
  config = yamldecode(file("/opt/workspace/workload-config.yaml"))
}


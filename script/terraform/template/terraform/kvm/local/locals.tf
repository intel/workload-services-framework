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
        cpu_set = profile.cpu_set==null?[]:split(",",profile.cpu_set)
        node_set = profile.node_set==null?[]:split(",",profile.node_set)
        os_image = profile.os_image
        os_type = profile.os_type
        os_disk_size = profile.os_disk_size
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
        network_spec = profile.network_spec!=null?profile.network_spec[i]:null
      } if element(profile.kvm_hosts,i) == var.kvm_index
    ]
  ])
}

locals {
  instances = {
    for vm in local.instances_flat : "${vm.profile}-${vm.index}" => {
      index = vm.index
      cpu_core_count = vm.cpu_core_count
      memory_size = vm.memory_size
      cpu_set = concat([
        for s in flatten([
          for e in vm.cpu_set:
            range(parseint(element(split("-",e),0),10),parseint(element(split(":",element(split("-",e),-1)),0),10)+1,strcontains(e,":")?parseint(element(split(":",e),-1),10):1)
            if !startswith(e,"^") && e != "auto"
        ]): s if !contains(flatten([
          for e in vm.cpu_set:
            range(parseint(element(split("-",trim(e,"^")),0),10),parseint(element(split(":",element(split("-",trim(e,"^")),-1)),0),10)+1,strcontains(e,":")?parseint(element(split(":",e),-1),10):1)
            if startswith(e,"^") && e != "auto"
        ]),s)
      ], [
        for e in vm.cpu_set: e
          if e == "auto"
      ])
      node_set = concat([
        for s in flatten([
          for e in vm.node_set:
            range(parseint(element(split("-",e),0),10),parseint(element(split(":",element(split("-",e),-1)),0),10)+1,strcontains(e,":")?parseint(element(split(":",e),-1),10):1)
            if !startswith(e,"^") && e != "auto"
        ]): s if !contains(flatten([
          for e in vm.node_set:
            range(parseint(element(split("-",trim(e,"^")),0),10),parseint(element(split(":",element(split("-",trim(e,"^")),-1)),0),10)+1,strcontains(e,":")?parseint(element(split(":",e),-1),10):1)
            if startswith(e,"^") && e != "auto"
        ]),s)
      ], [
        for e in vm.node_set: e
          if e == "auto"
      ])
      profile = vm.profile
      os_image = vm.os_image
      os_type = vm.os_type
      os_disk_size = vm.os_disk_size
      data_disk_spec = vm.data_disk_spec
      network_spec = vm.network_spec
    }
  }
}


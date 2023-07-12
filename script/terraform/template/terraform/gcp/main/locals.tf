#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
locals {
  vms_flat = flatten([
    for profile in var.instance_profiles : [
      for i in range(profile.vm_count): {
        index = i
        profile = profile.name
        os_image = profile.os_image
        instance_type = profile.instance_type
        cpu_model_regex = profile.cpu_model_regex
        os_disk_type = profile.os_disk_type
        os_disk_size = profile.os_disk_size
        min_cpu_platform = profile.min_cpu_platform
        threads_per_core = profile.threads_per_core
        cpu_core_count = profile.cpu_core_count
        nic_type = profile.nic_type
        os_type = profile.os_type
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
        network_spec = profile.network_spec!=null?profile.network_spec[i]:null
      }
    ]
  ])
  vms = {
    for vm in local.vms_flat : "${vm.profile}-${vm.index}" => {
      os_image = vm.os_image
      instance_type = vm.instance_type
      cpu_model_regex = vm.cpu_model_regex
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      min_cpu_platform = vm.min_cpu_platform
      threads_per_core = vm.threads_per_core
      cpu_core_count = vm.cpu_core_count
      os_type = vm.os_type
      data_disk_spec = vm.data_disk_spec
      network_spec = vm.network_spec
      nic_type = vm.nic_type
    }
  }
}

locals {
  project_id = var.project_id != null? var.project_id: jsondecode(file("~/.config/gcloud/application_default_credentials.json"))["quota_project_id"]
}

locals {
  networks_flat = flatten([
    for k,v in local.vms : [
      for i in range(v.network_spec!=null?v.network_spec.network_count:0) : {
        name         = "network-interface-${i+1}"
        instance     = k
        lun          = i+1
      }
    ]
  ])
  networks = {
    for net in local.networks_flat : net.name => {
      instance     = net.instance
      lun          = net.lun
    }
  }
  cidrs = {
    for lun in distinct([
      for k,v in local.networks : v.lun
    ]): tostring(lun) => lun
  }
}


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
        instance_type = profile.instance_type
        os_image = profile.os_image
        os_type = profile.os_type
        os_disk_type = profile.os_disk_type
        os_disk_size = profile.os_disk_size
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
        network_spec = profile.network_spec!=null?profile.network_spec[i]:null
      }
    ]
  ])
}

locals {
  vms = {
    for vm in local.vms_flat : "${vm.profile}-${vm.index}" => {
      instance_type = vm.instance_type
      os_image = vm.os_image
      os_type = vm.os_type
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      data_disk_spec = vm.data_disk_spec
      network_spec = vm.network_spec
    }
  }
}

locals {
  subnet_cidr_block = cidrsubnet(var.vpc_cidr_block, 8, 1)
}

locals {
  subnet_cidr_block_private = cidrsubnet(var.vpc_cidr_block, 8, 2)
}

locals {
  availability_zone = length(regexall("-[0-9]$",var.zone))>0?parseint(replace(var.zone,"/.*-/",""),10):1
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
}

locals {
  config = yamldecode(file("/opt/workspace/workload-config.yaml"))
  config_map = local.config.tunables
}

locals {
  elastic_pool_sku_arg = {
    tier     = local.config_map["ELASTIC_POOL_SKU_TIER"]
    capacity = local.config_map["ELASTIC_POOL_SKU_CAPACITY"]
  }
}

locals {
  elastic_pool_vcore_family = local.config_map["ELASTIC_POOL_VCORE_FAMILY"]
}

locals {
  vcore_tiers                 = ["GeneralPurpose", "BusinessCritical"]
  elastic_pool_vcore_sku_name = local.elastic_pool_sku_arg != null ? format("%s_%s", local.elastic_pool_sku_arg.tier == "GeneralPurpose" ? "GP" : "BC", local.elastic_pool_vcore_family) : null
  elastic_pool_dtu_sku_name   = local.elastic_pool_sku_arg != null ? format("%sPool", local.elastic_pool_sku_arg.tier) : null
  elastic_pool_sku = local.elastic_pool_sku_arg != null ? {
    name     = contains(local.vcore_tiers, local.elastic_pool_sku_arg.tier) ? local.elastic_pool_vcore_sku_name : local.elastic_pool_dtu_sku_name
    capacity = local.elastic_pool_sku_arg.capacity
    tier     = local.elastic_pool_sku_arg.tier
    family   = contains(local.vcore_tiers, local.elastic_pool_sku_arg.tier) ? local.elastic_pool_vcore_family : null
  } : null
}

locals {
  sku_name = local.config_map["SINGLE_DATABASES_SKU_NAME"]
}

locals {
  elastic_pool_enabled = local.config_map["ELASTIC_POOL_ENABLED"]
}

locals {
  elastic_pool_license = local.elastic_pool_enabled ? local.elastic_pool_sku_arg.tier == "GeneralPurpose" || local.elastic_pool_sku_arg.tier == "BusinessCritical" ? "LicenseIncluded " : null : "LicenseIncluded"
}

locals {
  min_capacity = local.elastic_pool_sku_arg.tier == "GeneralPurpose" || local.elastic_pool_sku_arg.tier == "BusinessCritical" ? 1 : 10
}


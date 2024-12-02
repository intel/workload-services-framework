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
        os_image = profile.os_image
        os_type = profile.os_type
        os_disk_type = profile.os_disk_type
        os_disk_size = profile.os_disk_size
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
      }
    ]
  ])
}

locals {
  instances = {
    for vm in local.instances_flat : "${vm.profile}-${vm.index}" => {
      instance_type = vm.instance_type
      os_image = vm.os_image
      profile = vm.profile
      os_type = vm.os_type
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      data_disk_spec = vm.data_disk_spec
    }
  }
}

locals {
  ondemand_instances = {
    for k,v in local.instances : k => v
  }
}

locals {
  profile_map = {
    for profile in var.instance_profiles: profile.name => profile
  }
}

locals {
  config = yamldecode(file("/opt/workspace/workload-config.yaml"))
  config_map = local.config.tunables
}

locals {
  mysql_config = [
    "max_connections",
    "table_open_cache",
    "table_open_cache_instances",
    "back_log",
    "performance_schema",
    "max_prepared_stmt_count",
    "character_set_server",
    "collation_server",
    "transaction_isolation",
    "innodb_file_per_table",
    "innodb_open_files",
    "innodb_buffer_pool_size",
    "innodb_flush_log_at_trx_commit",
    "join_buffer_size",
    "sort_buffer_size",
    "innodb_stats_persistent",
    "innodb_spin_wait_delay",
    "innodb_max_purge_lag_delay",
    "innodb_max_purge_lag",
    "innodb_lru_scan_depth",
    "innodb_purge_threads",
    "innodb_adaptive_hash_index",
    "innodb_sync_spin_loops"
  ]
}

locals  {
  need_reboot_config = [
    "table_open_cache_instances",
    "back_log",
    "performance_schema",
    "innodb_open_files",
    "innodb_purge_threads"
  ]
}

locals {
  custom_database_parameters = [
    for key, value in local.config_map: {
      name = key
      value = local.config_map[key]
      apply_method = contains(local.need_reboot_config, key)?"pending-reboot":null
    } if contains(local.mysql_config, key)
  ]
}

locals {
  instance_class = local.config_map["INSTANCE_CLASS"]
}

locals {
  identifier = var.common_tags["owner"]
}



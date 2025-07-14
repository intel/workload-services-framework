#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: {}
ifelse(HERO_FEATURE_IAA,true,`dnl
  HAS-SETUP-IAA: required
')dnl
ifelse(HERO_FEATURE_QAT,true,`dnl
  HAS-SETUP-QAT-V200: required
  HAS-SETUP-HUGEPAGE-2048kB-4096: required
')dnl
ifelse(DISK_SPEC,true,`dnl
  HAS-SETUP-DISK-MOUNT-1: required
')dnl
  vm_group: worker
  bios:
    SE5C7411.86B:
      "Intel(R) Hyper-Threading Tech": Enabled          # "Disabled"
      "CPU Power and Performance Policy": Performance   # "Balanced Performance", "Balanced Power", or "Power"
      "Intel(R) Turbo Boost Technology": Enabled        # "Disabled"
    SE5C620.86B:
      "Intel(R) Hyper-Threading Tech": Enabled          # "Disabled"
      "CPU Power and Performance Policy": Performance   # "Balanced Performance", "Balanced Power", or "Power"
      "Intel(R) Turbo Boost Technology": Enabled        # "Disabled"
    EGSDCRB1.86B:
      ProcessorHyperThreadingDisable: "ALL LPs"         # "Single LP"
      ProcessorEppProfile: Performance                  # "Balanced Performance", "Balanced Power", or "Power"
      EnableItbm: Enable                                # "Disable"
    EGSDCRB1.SYS:
      ProcessorHyperThreadingDisable: "ALL LPs"         # "Single LP"
      ProcessorEppProfile: Performance                  # "Balanced Performance", "Balanced Power", or "Power"
      EnableItbm: Enable                                # "Disable"
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
    /sys/devices/system/cpu/cpu*/power/energy_perf_bias: 0
ifelse(CORE_FREQUENCY_ENABLE,true,`dnl
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq: CORE_FREQUENCY
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq: CORE_FREQUENCY
')dnl
ifelse(UNCORE_FREQUENCY_ENABLE,true,`dnl
    /sys/devices/system/cpu/intel_uncore_frequency/uncore0*/min_freq_khz: UNCORE_FREQUENCY
    /sys/devices/system/cpu/intel_uncore_frequency/uncore0*/max_freq_khz: UNCORE_FREQUENCY
')dnl

ifelse(DB_HUGEPAGE_STATUS,true,`dnl
    /sys/kernel/mm/transparent_hugepage/enabled: always
    /sys/kernel/mm/transparent_hugepage/defrag: always
',
`dnl
    /sys/kernel/mm/transparent_hugepage/enabled: never
    /sys/kernel/mm/transparent_hugepage/defrag: never
')dnl
ifelse(KERNEL_SETTING_OPTIMIZED,true,`dnl
    /proc/sys/vm/zone_reclaim_mode: 0
    /proc/sys/kernel/numa_balancing: 1
',)dnl
loop(`i', `0', eval(CLIENT_COUNT-1), `dnl 
- labels: {}
  vm_group: client
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
')dnl

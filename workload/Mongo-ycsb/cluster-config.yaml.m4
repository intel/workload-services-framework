#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: {}
ifelse(DISK_SPEC,true,`dnl
  HAS-SETUP-DISK-MOUNT-1: required
')dnl
  vm_group: worker
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
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

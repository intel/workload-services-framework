#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(TESTCASE,_pkm),-1,, `dnl
- labels: {}
  vm_group: client
')
loop(`i', `1', HOST_NUM, `dnl
- labels: {}
  vm_group: worker
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
    /sys/devices/system/cpu/cpu*/power/energy_perf_bias: 0
ifelse(CORE_FREQUENCY_ENABLE,true,`dnl
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq: CORE_FREQUENCY
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq: CORE_FREQUENCY
')
ifelse(UNCORE_FREQUENCY_ENABLE,true,`dnl
    /sys/devices/system/cpu/intel_uncore_frequency/uncore0*/min_freq_khz: UNCORE_FREQUENCY
    /sys/devices/system/cpu/intel_uncore_frequency/uncore0*/max_freq_khz: UNCORE_FREQUENCY
')
ifelse(CASSANDRA_DISK_MOUNT,true,`dnl
    HAS-SETUP-DISK-MOUNT-1: required
')
')
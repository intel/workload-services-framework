#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: {}
  vm_group: worker
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
ifelse(RUN_SINGLE_NODE,false,`dnl
- labels: {}
  vm_group: client
ifelse(eval(ifelse(index(TESTCASE,_gated),-1,1,0) && ifelse(CLIENT_COUNT,1,0,1)),1,`dnl
- labels: {}
  vm_group: client
ifelse(CLIENT_COUNT,3,`dnl
- labels: {}
  vm_group: client
',)
',)
',)
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

# The cluster-config.yaml.m4 manifest specifies the workload running environment. 
# For the simple dummy workload, the manifest requests to run the workload on a 
# single-node cluster, without any special requirement of host setup. See 
# doc/developer-guide/component-design/cluster-config.md for full documentation.

cluster:
- labels: {}
  vm_group: worker
  traceable: true  
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
    /sys/devices/system/cpu/cpu*/power/energy_perf_bias: 0
ifelse(CORE_FREQUENCY_ENABLE,true,`dnl
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq: CORE_FREQUENCY
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq: CORE_FREQUENCY
')dnl

loop(`i', `0', eval(CLIENT_COUNT-1), `dnl 
- labels: {}
  vm_group: client
  traceable: false
')dnl
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
loop(`i', `0', eval(CLIENT_COUNT-1), `dnl 
- labels: {}
  vm_group: client
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
')dnl
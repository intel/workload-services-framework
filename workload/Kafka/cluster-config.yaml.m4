#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(TESTCASE,_1n),-1,,`dnl
- labels: {}
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
')
ifelse(index(TESTCASE,_3n),-1,,`dnl
- labels: {}
  vm_group: client
- labels: {}
  vm_group: client
')
ifelse(index(TESTCASE,_3n),-1,,`loop(`i', `1', BROKER_SERVER_NUM, `dnl
- labels: ifelse(ENABLE_MUL_DISK,true,`
    HAS-SETUP-DISK-SPEC-1: required',`{}')
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
')')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)


cluster:
loop(`i', `1', NUM_NODES, `dnl
  - labels: ifelse(MOUNT_DISK,true,`
      HAS-SETUP-DISK-SPEC-1: required
',` {}')
    sysfs:
      /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
      /sys/kernel/mm/transparent_hugepage/enabled: never
      /sys/kernel/mm/transparent_hugepage/defrag: never

')dnl

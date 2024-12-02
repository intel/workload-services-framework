#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: {}

  sysfs:
    /sys/devices/system/cpu/cpu/power/energy_perf_bias: 0
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance

ifelse("defn(`THP_ENABLE')","always",`dnl
    /sys/kernel/mm/transparent_hugepage/enabled: always
',`dnl
    /sys/kernel/mm/transparent_hugepage/enabled: never
')dnl


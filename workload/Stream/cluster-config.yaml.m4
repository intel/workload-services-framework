#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: {}

  sysfs:
    /sys/kernel/mm/transparent_hugepage/enabled : never

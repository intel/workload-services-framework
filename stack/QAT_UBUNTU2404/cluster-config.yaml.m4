#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(STACK,`qathw'),-1,`dnl
- labels: {}
',`dnl
- labels:
    HAS-SETUP-QAT: required
')dnl 

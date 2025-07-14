#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: 
    {}
loop(`i', `0', DORIS_BE_NUM, `dnl
- labels:
    {}
')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

define(K_NNODES)
cluster:
ifelse(ifdef(K_NNODES, 1, -1), -1, `dnl
- labels:
    HAS-SETUP-BKC-AI: preferred
', `loop(`i', `1', K_NNODES, `dnl
- labels:
    HAS-SETUP-BKC-AI: preferred
')')
 

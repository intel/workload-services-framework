#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:

ifelse("defn(`K_DECODER_BACKEND')","GPU",`dnl
    - labels: 
        HAS-SETUP-INTEL-ATSM: required
',`dnl

ifelse("defn(`K_MODEL_BACKEND')","GPU",`dnl
    - labels: 
        HAS-SETUP-INTEL-ATSM: required
',`dnl
    - labels: 
        {}
')dnl
')dnl





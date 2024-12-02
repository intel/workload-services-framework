#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(WORKLOAD,`_sgx'),-1,`dnl
- labels:
    HAS-SETUP-MODULE-MSR: required
    HAS-SETUP-HUGEPAGE-defn(`HUGEPAGE_SIZE_KB')kB-defn(`HUGEPAGE_NUMBER_OF_PAGES'): required
',`dnl
- labels:
    HAS-SETUP-MODULE-MSR: required
    HAS-SETUP-GRAMINE-SGX: required
')

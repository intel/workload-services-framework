#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(defn(`NODE'),3,`dnl
- labels: {}
  vm_group: client
- labels: {}
  vm_group: client
')dnl
ifelse(defn(`NODE'),2,`dnl
- labels: {}
  vm_group: client
')dnl
ifelse(defn(`NODE'),1,`dnl
')dnl
ifelse(index(WORKLOAD,`_sgx'),-1,`dnl
ifelse(index(WORKLOAD,`_qathw'),-1,`dnl
- labels: {}
  vm_group: worker
',`dnl
- labels:
    HAS-SETUP-QAT-V200: required
    HAS-SETUP-HUGEPAGE-2048kB-4096: required
  vm_group: worker
')dnl
',`dnl
- labels: 
    HAS-SETUP-GRAMINE-SGX: required
  vm_group: worker
')dnl
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
terraform:
    k8s_plugins: [qat-plugin]
')dnl

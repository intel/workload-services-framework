#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(TESTCASE,_2n),-1,`dnl
ifelse(index(CRYPTO_ACC,`qathw'),-1,`dnl
ifelse(index(DLB_ACC,`dlb'),-1,`dnl
- labels: {}'
,`dnl
- labels:
    HAS-SETUP-DLB: required
')dnl
',`dnl
- labels:
    HAS-SETUP-QAT-V200: required
    HAS-SETUP-HUGEPAGE-2048kB-4096: required
')dnl
  vm_group: worker
',`dnl
ifelse(index(CRYPTO_ACC,`qathw'),-1,`dnl
ifelse(index(DLB_ACC,`dlb'),-1,`dnl
- labels: {}'
,`dnl
- labels:
    HAS-SETUP-DLB: required
')dnl
',`dnl
- labels:
    HAS-SETUP-QAT-V200: required
    HAS-SETUP-HUGEPAGE-2048kB-4096: required
')dnl
  vm_group: worker
- labels: {}
  vm_group: client
')dnl

terraform:
  k8s_kubeadm_options:
    KubeletConfiguration:
      cpuManagerPolicy: static
      systemReserved:
        cpu: 200m
  wl_kernel_modules: [br_netfilter,nf_nat,xt_REDIRECT,xt_owner,iptable_nat,iptable_mangle,iptable_filter]
ifelse(index(CRYPTO_ACC,`qathw'),-1,,`dnl
  k8s_plugins: [qat-plugin]
')dnl
ifelse(index(DLB_ACC,`dlb'),-1,,`dnl
  k8s_plugins: [dlb-plugin]
')dnl
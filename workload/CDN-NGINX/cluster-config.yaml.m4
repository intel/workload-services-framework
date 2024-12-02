#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(defn(`GATED'),gated,`dnl
- labels: {}
',`dnl
ifelse(index(WORKLOAD,`_qathw'),-1,`dnl
- labels:
    HAS-SETUP-DISK-SPEC-1: required
    HAS-SETUP-NIC-100G: required
ifelse(defn(`NODE'),3n,`dnl
- labels:
    HAS-SETUP-NIC-100G: required
',`')dnl
  vm_group: worker
',`dnl
- labels:
    HAS-SETUP-QAT: required
    HAS-SETUP-HUGEPAGE-2048kB-4096: required
    HAS-SETUP-DISK-SPEC-1: required
    HAS-SETUP-NIC-100G: required
ifelse(defn(`NODE'),3n,`dnl
- labels:
    HAS-SETUP-NIC-100G: required
')dnl
  vm_group: worker
')dnl  
')dnl
ifelse(defn(`GATED'),gated,`',`dnl
- labels:
    HAS-SETUP-NIC-100G: required
  off_cluster: true
  vm_group: client
')dnl
ifelse(defn(`GATED'),gated,`',`dnl
terraform:
  wrk_image: IMAGENAME(Dockerfile.1.wrk)
  wrklog_image: IMAGENAME(Dockerfile.1.wrklog)
  qat_policy: 1
  k8s_plugins:
  - local-static-provisioner
')dnl
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
ifelse(defn(`GATED'),gated,`dnl
terraform:
  k8s_plugins:
',`')dnl
  - qat-plugin
')dnl

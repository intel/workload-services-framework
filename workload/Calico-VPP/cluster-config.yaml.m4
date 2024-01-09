#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: 
    HAS-SETUP-HUGEPAGE-defn(`PER_HUGEPAGE_SIZE')kB-defn(`HUGEPAGES'): required
    HAS-SETUP-MODULE-VFIO-PCI: required
    HAS-SETUP-NIC-100G: required
- labels: 
    HAS-SETUP-HUGEPAGE-defn(`PER_HUGEPAGE_SIZE')kB-defn(`HUGEPAGES'): required
    HAS-SETUP-MODULE-VFIO-PCI: required 
    HAS-SETUP-NIC-100G: required

terraform:
  k8s_reset: true
  k8s_enable_registry: false
  k8s_cni: calicovpp
  k8s_version: '1.24.4'
  k8s_calicovpp_version: "v3.23.0"
  k8s_calicovpp_dsa_image_version: defn(`RELEASE')
  k8s_calicovpp_l3fwd_image_version: defn(`RELEASE')
  k8s_calico_mtu: defn(`MTU')
  k8s_calicovpp_buffer_data_size: ifelse(defn(`MTU'), 9000, 10240, 2048)
  k8s_calicovpp_cores: defn(`CORE_SIZE')
  k8s_calicovpp_core_start: defn(`VPP_CORE_START')
  k8s_calicovpp_dsa_enable: defn(`ENABLE_DSA')
  k8s_calicovpp_l3fwd_enable: true
  k8s_calicovpp_l3fwd_core_start: defn(`L3FWD_CORE_START')
  k8s_calicovpp_trex_image_version: defn(`RELEASE')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

# No special need for initiator currently, just need the kernel support 
# nvme-tcp function,and loaded the nvme-core and nvme-tcp module.
cluster:
- labels: 
    HAS-SETUP-DISK-SPEC-1: "required"
    HAS-SETUP-HUGEPAGE-2048kB-4096: "required"
    HAS-SETUP-MODULE-VFIO-PCI: "required"
    HAS-SETUP-DSA: "required"
    HAS-SETUP-NETWORK-SPEC-1: "required"
- labels:
    HAS-SETUP-NVMETCP: "required"
    HAS-SETUP-NETWORK-SPEC-1: "required"

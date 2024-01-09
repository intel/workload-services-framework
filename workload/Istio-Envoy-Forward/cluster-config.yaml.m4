#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels:
    HAS-SETUP-MODULE-BR-NETFILTER: required
    HAS-SETUP-MODULE-NF-NAT: required
    HAS-SETUP-MODULE-XT-REDIRECT: required
    HAS-SETUP-MODULE-XT-OWNER: required
    HAS-SETUP-MODULE-IPTABLE-NAT: required
    HAS-SETUP-MODULE-IPTABLE-MANGLE: required
    HAS-SETUP-MODULE-IPTABLE-FILTER: required
  vm_group: client
- labels:
    HAS-SETUP-MODULE-BR-NETFILTER: required
    HAS-SETUP-MODULE-NF-NAT: required
    HAS-SETUP-MODULE-XT-REDIRECT: required
    HAS-SETUP-MODULE-XT-OWNER: required
    HAS-SETUP-MODULE-IPTABLE-NAT: required
    HAS-SETUP-MODULE-IPTABLE-MANGLE: required
    HAS-SETUP-MODULE-IPTABLE-FILTER: required
  vm_group: worker

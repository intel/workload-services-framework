#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels:
    HAS-SETUP-HUGEPAGE-2048kB-HUGEPAGE_NUM_TOTAL: required
  sysctls:
    net.core.netdev_max_backlog: 655560
    net.core.rmem_max: 12582912
    net.core.somaxconn: 131072
    net.core.wmem_max: 12582912
    net.ipv4.ip_local_port_range: "1024 65535"
    net.ipv4.tcp_fin_timeout: 15
    net.ipv4.tcp_max_syn_backlog: 131072
    net.ipv4.tcp_mem: "6173031	8230709	12346062"
    net.ipv4.tcp_rmem: "10240 87380 12582912"
    net.ipv4.tcp_tw_reuse: 1
    net.ipv4.tcp_wmem: "10240 87380 12582912"
    net.ipv4.udp_mem: "12346062 16461419 24692124"
  vm_group: worker
ifelse(index(TESTCASE,2n),-1,,`dnl
- labels: {}
  sysctls:
    net.core.netdev_max_backlog: 655560
    net.core.somaxconn: 65535
    net.core.wmem_max: 12582912
    net.ipv4.tcp_max_syn_backlog: 131072
    net.ipv4.tcp_tw_reuse: 1
  vm_group: client
')
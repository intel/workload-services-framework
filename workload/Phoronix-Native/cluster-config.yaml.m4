#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels: {}
  sysfs:
  ifelse(defn(`BENCHMARK_WL'), `pts/stream-1.3.4', `
    /proc/sys/vm/drop_caches: 3
    /proc/sys/vm/compact_memory: 1
    /sys/kernel/mm/transparent_hugepage/enabled: always
  ', `
    /proc/sys/net/ipv4/tcp_tw_reuse: 1
    /proc/sys/net/ipv4/tcp_tw_recycle: 0
    /proc/sys/net/ipv4/tcp_fin_timeout: 45
    /proc/sys/net/core/netdev_max_backlog: 10000
    /proc/sys/net/ipv4/tcp_max_syn_backlog: 12048
    /proc/sys/net/core/somaxconn: 16384
    /proc/sys/net/netfilter/nf_conntrack_max: 512000
    /proc/sys/net/ipv4/tcp_syncookies: 1
    /proc/sys/net/core/rmem_max: 16777216
    /proc/sys/net/core/wmem_max: 16777216
    /proc/sys/net/core/rmem_default: 16777216
    /proc/sys/net/core/wmem_default: 16777216
    /proc/sys/net/core/optmem_max: 40960
    /proc/sys/net/ipv4/tcp_rmem: 4096 87380 16777216
    /proc/sys/net/ipv4/tcp_wmem: 4096 87380 16777216
    /proc/sys/net/ipv4/ip_local_port_range: 1024 65535
    /proc/sys/vm/max_map_count: 1048575
  ')

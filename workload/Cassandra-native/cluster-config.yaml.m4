#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:

- labels: {}
  sysfs:
    /sys/class/block/nvme*/queue/read_ahead_kb: 8
    /sys/class/block/nvme*/queue/rotational: 0
    /sys/class/block/nvme*/queue/scheduler: none
    /proc/sys/net/ipv4/tcp_keepalive_time: 60
    /proc/sys/net/ipv4/tcp_keepalive_probes: 3
    /proc/sys/net/ipv4/tcp_keepalive_intvl: 10
    /proc/sys/net/core/rmem_max: 16777216
    /proc/sys/net/core/wmem_max: 16777216
    /proc/sys/net/core/rmem_default: 16777216
    /proc/sys/net/core/wmem_default: 16777216
    /proc/sys/net/core/optmem_max: 40960
    /proc/sys/net/ipv4/tcp_rmem: '4096 87380 16777216'
    /proc/sys/net/ipv4/tcp_wmem: '4096 65536 16777216'
  vm_group: worker

- labels: {}
  vm_group: client


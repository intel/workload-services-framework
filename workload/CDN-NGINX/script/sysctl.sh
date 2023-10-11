#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.ip_local_reserved_ports=30000-32767
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.bridge.bridge-nf-call-arptables=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl -w net.core.wmem_max=568435456
sudo sysctl -w net.core.rmem_max=568435456
sudo sysctl -w "net.ipv4.tcp_rmem= 10240 8738000 125829120"
sudo sysctl -w "net.ipv4.tcp_wmem= 10240 8738000 125829120"
sudo sysctl -w net.ipv4.tcp_timestamps=0
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=8192
sudo sysctl -w net.ipv4.tcp_max_tw_buckets=5000
sudo sysctl -w net.ipv4.tcp_sack=1
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.tcp_tw_reuse=1
sudo sysctl -w "net.ipv4.ip_local_port_range=9000 65535"
sudo sysctl -w net.ipv4.ip_nonlocal_bind=1
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_low_latency=1
sudo sysctl -w net.core.netdev_max_backlog=250000
sudo sysctl -w fs.file-max=99999999
sudo sysctl -w fs.nr_open=99999999
sudo sysctl -w fs.aio-max-nr=1048576
sudo sysctl -w vm.vfs_cache_pressure=1000
sudo sysctl -w kernel.msgmax=65536
sudo sysctl -w kernel.shmmax=68719476736
sudo sysctl -w net.ipv4.tcp_window_scaling=1
sudo sysctl -w vm.swappiness=0
sudo sysctl -w net.ipv4.tcp_syn_retries=2
sudo sysctl -w net.ipv4.tcp_keepalive_time=1200
sudo sysctl -w net.ipv4.tcp_orphan_retries=3
sudo sysctl -w net.ipv4.tcp_syncookies=1
sudo sysctl -w net.ipv4.tcp_fin_timeout=60
sudo sysctl -w net.ipv4.tcp_keepalive_probes=5
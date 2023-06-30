#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

# Define the cluster node requirement for cumulus test.
# For typical ceph cluster benchamrk architecture, we need several nodes used for
# benchmark clients, and select 3 nodes for ceph server clusters.
# Currently, we combine the test client on ceph server clusters. only select 3-nodes
# for current design.Later we need to seperate the clients(2-3nodes) and servers(3nodes).
cluster:
- labels:
    HAS-SETUP-CEPH-STORAGE: "required"
    HAS-SETUP-HUGEPAGE-2048kB-32768: "required"
ifelse("defn(`CLUSTERNODES')","2",`dnl
- labels:
    HAS-SETUP-CEPH-STORAGE: "required"
    HAS-SETUP-HUGEPAGE-2048kB-32768: "required"
',ifelse("eval(defn(`CLUSTERNODES') > 2)","1",`dnl
- labels:
    HAS-SETUP-CEPH-STORAGE: "required"
    HAS-SETUP-HUGEPAGE-2048kB-32768: "required"
- labels:
    HAS-SETUP-CEPH-STORAGE: "required"
    HAS-SETUP-HUGEPAGE-2048kB-32768: "required"
',))dnl
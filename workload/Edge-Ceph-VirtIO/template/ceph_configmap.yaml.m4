#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: rook-config-override
  namespace: defn(`ROOK_CEPH_STORAGE_NS')
  #namespace: rook-ceph # namespace:cluster
data:
  config: |
ifelse("defn(`CLUSTERNODES')","1",`dnl
    [global]
    osd_pool_default_size = 1
    mon_warn_on_pool_no_redundancy = false
    bdev_flock_retry = 20
    bluefs_buffered_io = false
    mon_data_avail_warn = 20
    auth_allow_insecure_global_id_reclaim = false
    debug_lockdep = 0/0
    debug_context = 0/0
    debug_crush = 0/0
    debug_buffer = 0/0
    debug_timer = 0/0
    debug_filer = 0/0
    debug_objecter = 0/0
    debug_rados = 0/0
    debug_rbd = 0/0
    debug_journaler = 0/0
    debug_objectcatcher = 0/0
    debug_client = 0/0
    debug_osd = 0/0
    debug_optracker = 0/0
    debug_objclass = 0/0
    debug_filestore = 0/0
    debug_journal = 0/0
    debug_ms = 0/0
    debug_monc = 0/0
    debug_tp = 0/0
    debug_auth = 0/0
    debug_finisher = 0/0
    debug_heartbeatmap = 0/0
    debug_perfcounter = 0/0
    debug_asok = 0/0
    debug_throttle = 0/0
    debug_mon = 0/0
    debug_paxos = 0/0
    debug_rgw = 0/0
',`dnl
    [global]
    mon_clock_drift_allowed = 1
    mon_data_avail_warn = 20
    auth_allow_insecure_global_id_reclaim = false
    osd_numa_node = 0
    mon_warn_on_pool_no_redundancy = false
    bdev_flock_retry = 20
    bluefs_buffered_io = false
    debug_lockdep = 0/0
    debug_context = 0/0
    debug_crush = 0/0
    debug_buffer = 0/0
    debug_timer = 0/0
    debug_filer = 0/0
    debug_objecter = 0/0
    debug_rados = 0/0
    debug_rbd = 0/0
    debug_journaler = 0/0
    debug_objectcatcher = 0/0
    debug_client = 0/0
    debug_osd = 0/0
    debug_optracker = 0/0
    debug_objclass = 0/0
    debug_filestore = 0/0
    debug_journal = 0/0
    debug_ms = 0/0
    debug_monc = 0/0
    debug_tp = 0/0
    debug_auth = 0/0
    debug_finisher = 0/0
    debug_heartbeatmap = 0/0
    debug_perfcounter = 0/0
    debug_asok = 0/0
    debug_throttle = 0/0
    debug_mon = 0/0
    debug_paxos = 0/0
    debug_rgw = 0/0
')dnl
    osd_memory_target = defn(`OSD_MEMORY_TARGET')
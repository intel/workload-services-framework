#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(TESTCASE,_pkm),-1,, `dnl
- labels: {}
  vm_group: client
')
loop(`i', `1', HOST_NUM, `dnl
ifelse(CASSANDRA_DISK_MOUNT,true,`- labels:',`- labels: {}')
ifelse(CASSANDRA_DISK_MOUNT,true,`dnl
    HAS-SETUP-DISK-MOUNT-1: required
')
')

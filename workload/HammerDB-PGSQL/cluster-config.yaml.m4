#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(RUN_SINGLE_NODE,false,`dnl
- labels: {}
  vm_group: client
')dnl

ifelse(HUGE_PAGES_STATUS,on,`- labels:',ENABLE_MOUNT_DIR,true,`- labels:',`- labels: {}')
ifelse(ENABLE_MOUNT_DIR,true,`dnl
    HAS-SETUP-DISK-MOUNT-1: required
')dnl
ifelse(index(TESTCASE, `hugepage_on'), -1,,`dnl
    define(`shared_buffers', `13')dnl # shared_buffers=12GB in postgresql.conf & plus 1
    define(`huge_page_size', `2')dnl # 2MB
    define(`huge_page_num', eval(shared_buffers * 1024 * DB_INSTANCE / huge_page_size))
    HAS-SETUP-HUGEPAGE-2048kB-huge_page_num: required
')dnl

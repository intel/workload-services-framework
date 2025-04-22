#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("redis_ycsb_ubuntu2404")
add_testcase(${workload}_default default)
add_testcase(${workload}_gated gated)
add_testcase(${workload}_pkm)
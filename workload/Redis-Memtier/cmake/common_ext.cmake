#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("redis_memtier_ubuntu2404")
add_testcase(${workload}_pkm)
add_testcase(${workload}_gated)
add_testcase(${workload}_write)
add_testcase(${workload}_20write80read)
add_testcase(${workload}_read)
add_testcase(${workload}_xwrite_yread)
add_testcase(${workload}_single_node)
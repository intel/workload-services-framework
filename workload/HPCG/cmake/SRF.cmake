#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("hpcg")
add_testcase(${workload}_single_node_generic_192_30_numa_1 single_node generic 192 30 numa 1)
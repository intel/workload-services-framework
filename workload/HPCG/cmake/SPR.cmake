#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("hpcg")

add_testcase(${workload}_single_node_avx512_192_30_numa_numa_threadcompact1_numa_gated single_node avx512 192 30 numa numa threadcompact1 numa)
add_testcase(${workload}_single_node_generic_192_30_numa_1 single_node generic 192 30 numa 1)
add_testcase(${workload}_single_node_avx512_192_1900_numa_numa_threadcompact1_numa_pkm single_node avx512 192 1900 numa numa threadcompact1 numa)
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("stream_amd_zen4_ubuntu24")
add_testcase(${workload}_avx3 "avx3")
add_testcase(${workload}_pkm  "avx3")
add_workload("stream_amd_aocc4_ubuntu24")
add_testcase(${workload}_pkm "avx3")
add_testcase(${workload}_avx2 "avx2")
add_testcase(${workload}_avx3 "avx3")
add_testcase(${workload}_sse "sse")
add_testcase(${workload}_avx_hpc "avx")
add_testcase(${workload}_sse_gated "sse")

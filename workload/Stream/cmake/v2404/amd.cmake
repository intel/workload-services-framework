#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("stream_amd_aocc4_ubuntu24")
add_testcase(${workload}_avx2 "avx2")
add_testcase(${workload}_sse "sse")
add_testcase(${workload}_sse_gated "sse")

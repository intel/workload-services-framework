#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("stream")
foreach (instruction_set "sse" "avx2" "avx3")
    add_testcase(${workload}_${instruction_set} "${instruction_set}")
endforeach()
add_testcase(${workload}_sse_gated)
add_testcase(${workload}_pkm)
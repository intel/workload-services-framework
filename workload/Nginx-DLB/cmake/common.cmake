#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("nginx-dlb")

if (BACKEND STREQUAL "terraform")
    add_testcase("${workload}_native" "disable")
    add_testcase("${workload}_pkm" "disable")
    add_testcase("${workload}_gated" "disable")
endif()
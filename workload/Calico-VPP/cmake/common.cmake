#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

add_workload("calicovpp")

if (BACKEND STREQUAL "terraform")
    add_testcase("${workload}_sw" "false")
    add_testcase("${workload}_pkm" "false")
    add_testcase("${workload}_gated" "false")
endif()

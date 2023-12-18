#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    add_workload("tpcds-spark")
    foreach (scale_factor "gated" "1" "pkm" "250" "500" "1000")
        add_testcase(${workload}_${scale_factor} "${scale_factor}")
    endforeach()
endif()

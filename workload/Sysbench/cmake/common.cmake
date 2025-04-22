#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    add_workload("sysbench")
    add_testcase(${workload}_gated "gated")
    foreach(model_option "cpu" "memory" "mysql" "mutex")
        add_testcase(${workload}_${model_option}_pkm ${model_option})
    endforeach()
endif()

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if(NOT BACKEND STREQUAL "docker")
    add_workload("hibench_terasort_jdk8u422")
    foreach(ENGINE "mapreduce" "spark")
        add_testcase(${workload}_${ENGINE}_gated ${ENGINE})
        add_testcase(${workload}_${ENGINE}_pkm ${ENGINE})
        add_testcase(${workload}_${ENGINE} ${ENGINE})
    endforeach()
endif()

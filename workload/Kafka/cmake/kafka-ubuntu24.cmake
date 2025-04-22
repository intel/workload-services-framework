#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    foreach(JDKVER 18 17 11 8)
        add_workload("kafka_openjdk-jdk${JDKVER}-ubuntu24")
        add_testcase(${workload}_1n default)
        add_testcase(${workload}_multinode default)
        add_testcase(${workload}_multinode_pkm default)
    endforeach()
endif()

if (NOT BACKEND STREQUAL "docker")
    foreach(JDKVER 17 11 8)
        add_workload("kafka_corretto-jdk${JDKVER}-ubuntu24")
        add_testcase(${workload}_multinode default)
    endforeach()
endif()
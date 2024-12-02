#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    foreach(JDKVER 18 17 11 8)
        add_stack("kafka-openjdk-jdk${JDKVER}")
        add_testcase(${stack}_version_check)
    endforeach()
endif()

if (NOT BACKEND STREQUAL "docker")
    foreach(JDKVER 17 11 8)
        add_stack("kafka-corretto-jdk${JDKVER}")
    endforeach()
endif()


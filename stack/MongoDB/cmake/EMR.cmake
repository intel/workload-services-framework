#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

if (NOT BACKEND STREQUAL "docker")
    foreach(MONGOVER 710)
        add_stack("mongodb${MONGOVER}_iaa")
        add_testcase(${stack}_sanity)
    endforeach()
endif()
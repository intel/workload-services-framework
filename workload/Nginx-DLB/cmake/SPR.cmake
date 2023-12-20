#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

if (BACKEND STREQUAL "terraform")
    add_testcase("${workload}_dlb" "enable")
endif()
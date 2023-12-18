#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    foreach(MONGOVER 604)
        add_stack("mongodb${MONGOVER}_base")
        add_testcase(${stack}_sanity)
    endforeach()
endif()
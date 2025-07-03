#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    foreach(PAIR "441;_base" "604;_base" "700;_base" "604;_redhat")
        list(GET PAIR 0 MONGOVER)
        list(GET PAIR 1 SUFFIX)
        add_stack("mongodb${MONGOVER}${SUFFIX}")
        add_testcase(${stack}_sanity)
    endforeach()
endif()
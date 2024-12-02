#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)
add_stack("qathw_setup")
add_stack("qathw_ssl1_fedora")
add_stack("qathw_ssl1_ubuntu")
add_testcase(${stack}_ldd qathw-ssl1-ubuntu-unit-test-1)
add_stack("qathw_ssl3_ubuntu")

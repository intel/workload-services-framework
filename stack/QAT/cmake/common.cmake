#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack("qatsw_ssl1_ubuntu")
add_testcase(${stack}_ldd qatsw-ssl1-ubuntu-unit-test-1)
add_stack("qatsw_ssl3_ubuntu")
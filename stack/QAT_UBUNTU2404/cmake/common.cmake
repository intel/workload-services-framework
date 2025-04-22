#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack("qatsw_ssl3_ubuntu2404")
add_testcase(${stack}_ldd qatsw-ssl3-ubuntu2404-unit-test-1)
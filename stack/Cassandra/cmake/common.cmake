#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack("cassandra-base")
add_testcase(${stack}_jdk11_is_server_up default)
add_testcase(${stack}_jdk14_is_server_up default)
add_testcase(${stack}_jdk11_is_chunk_length_correct default)
add_testcase(${stack}_jdk14_is_chunk_length_correct default)
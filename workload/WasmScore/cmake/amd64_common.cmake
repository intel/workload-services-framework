#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("wasmscore")
add_testcase(${workload}_amd64)
add_testcase(${workload}_amd64_gated)
add_testcase(${workload}_amd64_pkm)
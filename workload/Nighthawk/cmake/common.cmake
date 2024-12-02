#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("nighthawk")
add_testcase("${workload}" "--duration=30" "--connections=8" "--concurrency=2" "--rps=30")
add_testcase("${workload}_gated" "--duration=30" "--connections=8" "--concurrency=2" "--rps=30")
add_testcase("${workload}_pkm" "--duration=30" "--connections=8" "--concurrency=2" "--rps=30")

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("stream_arm_ubuntu24")
add_testcase(${workload}_pkm "gcc")
add_testcase(${workload}_gated "sve")
add_testcase(${workload}_sve2 "sve2")
add_testcase(${workload}_sve "sve")

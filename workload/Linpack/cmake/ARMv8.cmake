#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("linpack_arm")

add_testcase(linpack_arm arm arm)
add_testcase(linpack_arm_pdt arm_pdt arm)

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("bertlarge_pytorch_arm")
add_testcase(${workload}_throughput_pkm)

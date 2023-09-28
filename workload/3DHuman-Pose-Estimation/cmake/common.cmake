#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("3dhuman_pose_estimation")
foreach (option 
        "latency_cpu_pytorch"
        "latency_cpu_openvino"
        "latency_gated"
        "latency_pkm")
    add_testcase(${workload}_${option} "${option}")
endforeach()
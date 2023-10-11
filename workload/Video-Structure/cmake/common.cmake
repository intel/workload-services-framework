#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("video_structure")

foreach (option 
        "Throughput_gated"
        "Throughput_1_1_yolon_3_0.3_9_person_2203_CPU_CPU"
        "Throughput_28_1_yolon_3_0.3_9_vehicle_2203_GPU_CPU"
        "Throughput_pkm" )
    add_testcase(${workload}_${option} "${option}")
endforeach()
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("SmartScienceLab")

add_testcase(${workload}_acc_inference "acc")
add_testcase(${workload}_fps_inference_gated "generic")
add_testcase(${workload}_fps_inference_pkm "generic")

foreach(ai_device "CPU")
    foreach(decode_device "CPU" "GPU")
        add_testcase(${workload}_fps_ai_device_${ai_device}_video_decode_${decode_device} ${ai_device} ${decode_device})
    endforeach()
endforeach()
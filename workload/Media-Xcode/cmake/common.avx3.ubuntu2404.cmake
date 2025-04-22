#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
foreach (option 
        "SVT-AV1-1080p-12-avx3" "SVT-AV1-1080p-10-avx3" "SVT-AV1-1080p-8-avx3" "SVT-AV1-1080p-6-avx3" "SVT-AV1-1080p-5-avx3" "SVT-AV1-4k-12-avx3" "SVT-AV1-4k-10-avx3" "SVT-AV1-4k-8-avx3" "SVT-HEVC-1080p-preset5-avx3" "SVT-HEVC-4k-preset9-avx3" "SVT-HEVC-4k-preset5-avx3" "SVT-HEVC-4k-preset1-avx3" "x265-1080p-medium-avx3" "x265-1080p-slow-avx3" "x265-4k-veryslow-avx3" "SVT-HEVC-1080p-preset7-avx3" 
        )
    foreach (compiler "gcc")
        foreach (scaling "generic")
            add_testcase(${workload}_${option}_${compiler}_${scaling} "${option}_${compiler}_${scaling}"  "ffmpeg")
        endforeach()
    endforeach()
endforeach()

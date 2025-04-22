#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_testcase(${workload}_SVT-AV1-1080p-8-avx2_gcc_generic_gated  "SVT-AV1-1080p-8-avx2_gcc_generic_gated" "ffmpeg")
add_testcase(${workload}_SVT-AV1-1080p-8-avx2_gcc_generic_pkm  "SVT-AV1-1080p-8-avx2_gcc_generic_pkm" "ffmpeg")
foreach (option 
        "SVT-AV1-1080p-12-avx2" "SVT-AV1-1080p-10-avx2" "SVT-AV1-1080p-8-avx2" "SVT-AV1-1080p-6-avx2" "SVT-AV1-1080p-5-avx2" "SVT-AV1-1080p-3-avx2" "SVT-AV1-4k-12-avx2" "SVT-AV1-4k-10-avx2" "SVT-AV1-4k-8-avx2" "SVT-HEVC-1080p-preset9-avx2" "SVT-HEVC-1080p-preset5-avx2" "SVT-HEVC-1080p-preset1-avx2" "SVT-HEVC-4k-preset9-avx2" "SVT-HEVC-4k-preset5-avx2" "AVC-1080p-fast-avx2" "AVC-1080p-medium-avx2" "AVC-1080p-veryslow-avx2" "x265-1080p-medium-avx2" "x265-1080p-slow-avx2" "x265-4k-veryslow-avx2" "SVT-HEVC-1080p-preset7-avx2"  
        )
    foreach (compiler "gcc")
        foreach (scaling "generic")
            add_testcase(${workload}_${option}_${compiler}_${scaling} "${option}_${compiler}_${scaling}"  "ffmpeg")
        endforeach()
    endforeach()
endforeach()

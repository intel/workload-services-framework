#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("ffmpegmediaxcode-x264-v60")
add_testcase(${workload}_AVC-1080p-fast-avx2_gcc_generic_gated  "AVC-1080p-fast-avx2_gcc_generic_gated" "ffmpeg")
add_testcase(${workload}_AVC-1080p-fast-avx2_gcc_generic_pkm  "AVC-1080p-fast-avx2_gcc_generic_pkm" "ffmpeg")
foreach (option
        "AVC-1080p-fast-avx2" "AVC-1080p-medium-avx2" "AVC-1080p-veryslow-avx2"
        )
    foreach (compiler "gcc")
        foreach (scaling "generic")
            add_testcase(${workload}_${option}_${compiler}_${scaling} "${option}_${compiler}_${scaling}"  "ffmpeg")
        endforeach()
    endforeach()
endforeach()

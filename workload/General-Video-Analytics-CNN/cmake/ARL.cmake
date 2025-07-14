#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

set(platform "arl")

foreach (vpu "" "-ivpu-bs1")
    foreach (device "igpu")
        foreach (model "light" "medium" "heavy")
            foreach(batchsize "1" "8")
                    add_testcase(${workload}_${platform}-${model}-${device}-bs${batchsize}${vpu} "${platform}-${model}-${device}-bs${batchsize}${vpu}" "")
            endforeach()
        endforeach()
    endforeach()
endforeach()

add_testcase(${workload}_${platform}-light-igpu-bs8_pkm "${platform}-light-igpu-bs8_pkm" "")
add_testcase(${workload}_${platform}-light-igpu-bs1_gated "${platform}-light-igpu-bs1_gated" "")

if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/../Dockerfile.1.dlstreamer.int.m4")
    add_workload("general-video-analytics-cnn-bmg")

    foreach (device "dgpu")
        foreach (model "light" "medium" "heavy")
            foreach(batchsize "1" "8")
                    add_testcase(${workload}_${platform}-${model}-${device}-bs${batchsize} "${platform}-${model}-${device}-bs${batchsize}" "BMG")
            endforeach()
        endforeach()
    endforeach()
endif()

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload(db_bench_rocksdbiaa)
foreach(type "readrandom" "readrandomwriterandom")
    if(NOT "${PLATFORM}" STREQUAL "ICX")
        add_testcase(${workload}_iaa_${type}_pkm "iaa" "${type}")
    endif()
        
    foreach(comp "zstd" "zlib" "lz4" "none")
        add_testcase(${workload}_${comp}_${type}_pkm "${comp}" "${type}")
    endforeach()

endforeach()

add_testcase(${workload}_zstd_readrandom_gated zstd readrandom)

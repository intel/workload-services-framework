#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack("rocksdb")

foreach(type "readrandom" "readrandomwriterandom")
    if(NOT "${PLATFORM}" STREQUAL "ICX")
        add_testcase(${stack}_iaa_${type}_pkm "iaa" "${type}")
    endif()
        
    foreach(comp "zstd")
        add_testcase(${stack}_${comp}_${type}_pkm "${comp}" "${type}")
    endforeach()

endforeach()

add_testcase(${stack}_zstd_readrandom_gated zstd readrandom)

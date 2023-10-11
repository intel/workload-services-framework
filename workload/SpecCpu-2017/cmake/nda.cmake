#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("speccpu_2017_v119_nda")

# icc-2023
set(platform_icc_2023_SPR "core-avx512")
set(platform_icc_2023_ICX "core-avx512")

set(compiler_icc_2023_SPR "ic2023.0-lin")
set(compiler_icc_2023_ICX "ic2023.0-lin")

set(release_icc_2023_SPR "20221201_intel")
set(release_icc_2023_ICX "20221201_intel")

foreach(benchmark fp int)
    add_testcase(${workload}_icc2023_${benchmark}speed ${compiler_icc_2023_${PLATFORM}} ${platform_icc_2023_${PLATFORM}} ${release_icc_2023_${PLATFORM}} ${benchmark}speed "base" 1)
    add_testcase(${workload}_icc2023_${benchmark}rate ${compiler_icc_2023_${PLATFORM}} ${platform_icc_2023_${PLATFORM}} ${release_icc_2023_${PLATFORM}} ${benchmark}rate "base")
endforeach()

# gcc-12
set(platform_gcc_SPR "sapphirerapids")
set(platform_gcc_ICX "icelake-server")

set(compiler_gcc_SPR "gcc12.1.0-lin")
set(compiler_gcc_ICX "gcc12.1.0-lin")

set(release_gcc_SPR "20220509")
set(release_gcc_ICX "20220509")

foreach(benchmark fp int)
    add_testcase(${workload}_gcc12_${benchmark}rate ${compiler_gcc_${PLATFORM}} ${platform_gcc_${PLATFORM}} ${release_gcc_${PLATFORM}} ${benchmark}rate "base")
    add_testcase(${workload}_gcc12_${benchmark}speed ${compiler_gcc_${PLATFORM}} ${platform_gcc_${PLATFORM}} ${release_gcc_${PLATFORM}} ${benchmark}speed "base" 1)
endforeach()

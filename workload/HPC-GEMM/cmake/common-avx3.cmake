#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("gemm_avx3")

foreach (type "sgemm" "dgemm")
    foreach (option "mkl" "blis")
        foreach(size "40000")
        foreach(threads "max")
            add_testcase(gemm_avx3_${type}_${option}_${size}_${threads} "avx3" "${type}" "${option}" "${size}" "${threads}")
        endforeach()
        endforeach()
    endforeach()
endforeach()  

add_testcase(gemm_avx3_sgemm_gated "avx3" "sgemm" "mkl" "4000" "max") 
add_testcase(gemm_avx3_dgemm_gated "avx3" "dgemm" "mkl" "4000" "max")
add_testcase(gemm_avx3_sgemm_pkm "avx3" "sgemm" "mkl" "40000" "max")
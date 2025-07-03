#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("gemm_avx2")

foreach (type "sgemm" "dgemm")
    foreach (option "mkl" "blis")
        foreach(size "40000")
        foreach(threads "max")
            add_testcase(gemm_avx2_${type}_${option}_${size}_${threads} "avx2" "${type}" "${option}" "${size}" "${threads}")
        endforeach()
        endforeach()
    endforeach()
endforeach()   

add_testcase(gemm_avx2_sgemm_gated "avx2" "sgemm" "mkl" "4000" "max") 
add_testcase(gemm_avx2_dgemm_gated "avx2" "dgemm" "mkl" "4000" "max")
add_testcase(gemm_avx2_sgemm_pkm "avx2" "sgemm" "mkl" "40000" "max")
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("malconv")
foreach (option 
        "tf_fp32_avx_single_1" 
        "tf_int8_avx_single_1" 
        "onnx_int8_avx_single_1" 
        "tf_int8_avx_single_1_pkm" 
        "tf_int8_avx_single_1_gated" )
    add_testcase(${workload}_${option} "${option}")
endforeach()
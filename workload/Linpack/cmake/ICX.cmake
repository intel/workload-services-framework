#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("linpack_intel")

add_testcase(linpack_intel_avx2_gated avx2_gated intel)
add_testcase(linpack_intel_avx2_pkm avx2_pkm intel)
add_testcase(linpack_intel_avx3_pdt avx3_pdt intel)

foreach( inst "sse2" "avx2" "avx3" )
	add_testcase(linpack_intel_${inst} ${inst} intel)
endforeach()
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("linpack_intel")

add_testcase(linpack_intel_avx2_gated avx2 intel)
add_testcase(linpack_intel_avx2_pkm avx2 intel)
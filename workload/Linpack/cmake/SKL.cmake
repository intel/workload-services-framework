#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common-intel.cmake)

foreach( inst "avx2" "avx3" )
	add_testcase(linpack_intel_${inst} ${inst} intel)
endforeach()

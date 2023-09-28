#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common-intel.cmake)

if(" SPR " MATCHES " ${PLATFORM} " AND " nova " MATCHES " ${BACKEND} " )
	add_testcase(linpack_intel_avx2_nova avx2 intel)
endif()

foreach( inst "avx2" "avx3" "sse" "default_instruction" )
	add_testcase(linpack_intel_${inst} ${inst} intel)
endforeach()
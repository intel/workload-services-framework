#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common-amd.cmake)

foreach( inst "avx2" )
	add_testcase(linpack_amd_${inst} ${inst} amd socket)
endforeach()
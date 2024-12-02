#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/cmake/common_ext.cmake)
include(cmake/common_ext.cmake OPTIONAL)
else()
include(cmake/common_int.cmake OPTIONAL)
endif()
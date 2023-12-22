#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/${PLATFORM}.cmake OPTIONAL)
if(NOT ${PLATFORM} STREQUAL "ICX")
    include(cmake/QAT.cmake OPTIONAL)
endif()
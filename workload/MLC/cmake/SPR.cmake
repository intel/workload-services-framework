#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

if(" nova " MATCHES " ${BACKEND} " )
    add_testcase(mlc_local_latency_nova "local_latency")
endif()


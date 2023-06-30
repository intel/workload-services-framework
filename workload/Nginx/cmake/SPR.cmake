#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)
add_workload("nginx_qathw")
foreach (node 1 2 3)
    foreach (mode https)
    add_testcase(intel_async_${workload}_async_${node}node_${mode} "${node}" "${mode}" async 4)
    endforeach()
endforeach()
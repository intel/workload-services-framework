#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

add_workload("nginx_original")
foreach (node 1 2 3)
    foreach (mode https)
        add_testcase(official_${workload}_${node}node_${mode} "${node}" "${mode}" off 4)
    endforeach()
endforeach()

add_workload("nginx_qatsw")
foreach (node 1 2 3)
    foreach (mode https)
    add_testcase(intel_async_${workload}_off_${node}node_${mode} "${node}" "${mode}" off 4)
    add_testcase(intel_async_${workload}_async_${node}node_${mode} "${node}" "${mode}" async 4)
    endforeach()
endforeach()

add_testcase(intel_async_${workload}_async_1node_https_gated 1 https async 1)
add_testcase(intel_async_${workload}_async_1node_https_pkm 1 https async 4)

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("nginx_original_${PLATFORM}")
foreach (node 1 2 3)
    foreach (mode https)
        add_testcase(official_${workload}_${node}node_${mode} "${node}" "${mode}" off 4)
    endforeach()
endforeach()

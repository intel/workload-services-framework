#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if(BACKEND STREQUAL "docker")
else()
    add_workload("hibench_kmeans")
    add_testcase(hibench_kmeans_gated)
    add_testcase(hibench_kmeans_pkm)
    add_testcase(hibench_kmeans_default)
endif()

#casename mongodb_ycsb_thr64_r90_u10_op10m_mongo3 means: thread=64, read=90% and update=10%, total 10m ops, 3 mongodb instances
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if (NOT BACKEND STREQUAL "docker")
    add_workload("ann-vectordb")
    add_testcase(${workload}_gated)
    add_testcase(${workload}_milvus_pkm "milvus")
    add_testcase(${workload}_redisearch_pkm "redisearch")
endif()

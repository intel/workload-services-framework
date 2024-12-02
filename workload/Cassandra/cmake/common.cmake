#WORKLOAD_FILE: usually, we use 90Read10Update
#THREADS: threads number of ycsb
#OPERATION_COUNT: operations will be done by ycsb
#RECORD_COUNT: records in mongodb
#INSERT_START: where insert start
#INSERT_COUNT: how many records inserted
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


#casename mongodb_ycsb_thr64_r90_u10_op10m_mongo3 means: thread=64, read=90% and update=10%, total 10m ops, 3 mongodb instances

if (NOT BACKEND STREQUAL "docker")
    add_workload("cassandra")
    add_testcase(${workload}_gated gated)
    add_testcase(${workload}_standalone_1n default)
    add_testcase(${workload}_standalone_2n_pkm default) 
    add_testcase(${workload}_cluster_pkm default)
endif()
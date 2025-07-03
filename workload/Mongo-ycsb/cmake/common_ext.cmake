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
    foreach(MONGOVER 441 604 700)
        add_workload("ycsb_mongodb${MONGOVER}_base")
        add_testcase("${workload}_gated")
        add_testcase("${workload}_pkm")
        add_testcase("${workload}_90read10update")        
        add_testcase("${workload}_30write70read")
        add_testcase("${workload}_50read50update")
        add_testcase("${workload}_write")
        add_testcase("${workload}_read")
    endforeach()
    foreach(SUFFIX redhat ubuntu2404)
        foreach(MONGOVER 604)
            add_workload("ycsb_mongodb${MONGOVER}_${SUFFIX}")
            add_testcase("${workload}_gated")
            add_testcase("${workload}_pkm")
            add_testcase("${workload}_90read10update")
            add_testcase("${workload}_30write70read")
            add_testcase("${workload}_50read50update")
            add_testcase("${workload}_write")
            add_testcase("${workload}_read")
        endforeach()
    endforeach()
endif()

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (BACKEND STREQUAL "terraform")
    add_workload("clickhouse_xdr_public_hyperscan")
    add_testcase(${workload}_baseline)
    add_testcase(${workload}_gated)
    add_testcase(${workload}_pkm)
endif()

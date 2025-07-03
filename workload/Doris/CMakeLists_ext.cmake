#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (" GNR SRF SPR EMR ICX " MATCHES " ${PLATFORM} ")
    add_workload("doris")
    add_testcase(${workload}_gated gated)
    add_testcase(${workload}_pkm pkm)
    add_testcase(${workload}_ssb default)
endif()

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set(nova_workload "ycsb_mongodb604_base")

add_testcase("${nova_workload}_90read10update_gated" "NOVA")
add_testcase("${nova_workload}_90read10update_pkm" "NOVA" "--nova_ini=trace_length=5000000000")
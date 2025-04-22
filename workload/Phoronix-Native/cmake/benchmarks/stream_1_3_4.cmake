#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("phoronix_stream_1.3.4")
add_testcase(${workload}_1node "pts/stream-1.3.4")
add_testcase(${workload}_1node_gated "pts/stream-1.3.4")
add_testcase(${workload}_1node_pkm "pts/stream-1.3.4")

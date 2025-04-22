#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("phoronix_nginx_3.0.1")
add_testcase(${workload}_1node "pts/nginx-3.0.1")
add_testcase(${workload}_1node_gated "pts/nginx-3.0.1")
add_testcase(${workload}_1node_pkm "pts/nginx-3.0.1")

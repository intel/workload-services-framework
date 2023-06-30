#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("openssl3_rsamb_qatsw")
string(REPLACE "_qatsw" "_sw" workload1 "${workload}")
foreach(algo "rsa" "dsa" "ecdsa" "ecdh" "aes-sha" "aes-gcm")
    add_testcase(${workload}_${algo})
    add_testcase(${workload1}_${algo} "sw-${algo}")
endforeach()
    add_testcase(${workload}_rsa_gated)

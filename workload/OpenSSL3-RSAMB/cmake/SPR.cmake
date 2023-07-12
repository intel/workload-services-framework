#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)
add_workload("openssl3_rsamb_qathw")
foreach(algo "rsa" "dsa" "ecdsa" "ecdh" "dh" "hkdf" "prf" "ecx" "chachapoly" "aes-sha" "aes-gcm")
    add_testcase(${workload}_${algo})
endforeach()
   add_testcase(${workload}_rsa_gated)
   add_testcase(${workload}_rsa_pkm)

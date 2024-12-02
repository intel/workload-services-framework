#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("hammerdb_tpcc_native")
add_testcase(${workload}_windows2019_mysql8033 "windows2019" "mysql8033")
add_testcase(${workload}_ubuntu2204_mysql8033 "ubuntu2204" "mysql8033")
add_testcase(${workload}_ubuntu2204_postgresql13 "ubuntu2204" "postgresql13")
add_testcase(${workload}_ubuntu2004_postgresql13 "ubuntu2004" "postgresql13")
add_testcase(${workload}_centos7_postgresql14 "centos7" "postgresql14")
add_testcase(${workload}_windows2016_postgresql14 "windows2016" "postgresql14")
add_testcase(${workload}_windows2016_postgresql14_pkm "windows2016" "postgresql14")
add_testcase(${workload}_ubuntu2204_postgresql13_gated "ubuntu2204" "postgresql13")
add_testcase(${workload}_ubuntu2204_mysql8033_gated "ubuntu2204" "mysql8033")
add_testcase(${workload}_centos9_postgresql14 "centos9" "postgresql14")
add_testcase(${workload}_windows2019_postgresql14 "windows2019" "postgresql14")
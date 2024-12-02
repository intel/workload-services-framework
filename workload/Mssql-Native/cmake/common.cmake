#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload(mssql_aws SUT aws)
add_testcase(${workload}_windows2019_sql2016 "windows2019" "sql2016")
add_testcase(${workload}_windows2016_sql2019 "windows2016" "sql2019")
add_testcase(${workload}_windows2016_sql2016_pkm "windows2019" "sql2016")
add_testcase(${workload}_windows2016_sql2016_gated "windows2019" "sql2016")
add_testcase(${workload}_windows2019_sql2019 "windows2019" "sql2019")

add_workload(mssql_azure SUT azure)
add_testcase(${workload}_windows2019_sql2016_pkm "windows2019" "sql2016")
add_testcase(${workload}_windows2019_sql2016_gated "windows2019" "sql2016")

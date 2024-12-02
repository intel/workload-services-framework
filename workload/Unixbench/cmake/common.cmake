#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("unixbench")
add_testcase(${workload}_allinone_pkm "allinone")
add_testcase(${workload}_allinone_gated "allinone")
foreach(test_case dhry2reg whetstone-double fsbuffer fstime fsdisk pipe context1 spawn execl shell1 shell8 syscall allinone)
    add_testcase(${workload}_${test_case}_benchmark "${test_case}")
endforeach()

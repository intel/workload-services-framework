#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
 add_workload("hammerdb-pgsql_ubuntu24")

# Define at least a _pkm test case (and no more than two) for the most common use case.
add_testcase(${workload}_hugepage_off_pkm )

# Define at least a gated test case for commit validation. The gated test case
# must be short and cover most of the workload features.
add_testcase(${workload}_hugepage_off_gated)

# Define additional test cases as needed
add_testcase(${workload}_hugepage_on )
add_testcase(${workload}_hugepage_off )
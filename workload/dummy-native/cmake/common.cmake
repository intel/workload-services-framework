#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The add_workload function defines a workload. The workload name must be unique
# and do not have special characters except _. You can specify additional
# constraints as additional parameters such as license constraints and platform
# constraints. See doc/cmakelists.txt.md for details.
add_workload("dummy_native")

# The add_testcase function adds a test case, which will be executed through
# validate.sh. The test case name must be unique and avoid any special
# characters except _. Any arguments to add_testcase will be passed literally
# to validate.sh. See CMakeLists.txt for details. You can define any number
# of test cases here but there are special test cases that every workload
# must have as follows:

# Define at least a _pkm test case (and no more than two) for the most common use case.
add_testcase(${workload}_pi_pkm 2000)

# Define at least a gated test case for commit validation. The gated test case
# must be short and cover most of the workload features.
add_testcase(${workload}_gated 2000)

# Define additional test cases as needed
add_testcase(${workload}_pi_fail 2000 1 10)
add_testcase(${workload}_pi_pass 2000 0 10)


#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload arguments
# mssql arguments
WIN_VER=${1:-"windows2016"}
SQL_VER=${2:-"sql2016"}

# HammerDB arguments
TPCC_NUM_WAREHOUSES=${TPCC_NUM_WAREHOUSES:-10}
TPCC_HAMMER_NUM_VIRTUAL_USERS=${TPCC_HAMMER_NUM_VIRTUAL_USERS:-2}
TPCC_MINUTES_OF_RAMPUP=${TPCC_MINUTES_OF_RAMPUP:-1}
TPCC_MINUTES_OF_DURATION=${TPCC_MINUTES_OF_DURATION:-1}
TPCC_TOTAL_ITERATIONS=${TPCC_TOTAL_ITERATIONS:-10000000}
TPCC_RUNTIMER_SECONDS=${TPCC_RUNTIMER_SECONDS:-600}
TPCC_WAIT_COMPLETE_MILLSECONDS=${TPCC_WAIT_COMPLETE_MILLSECONDS:-5000}
TPCC_THREADS_BUILD_SCHEMA=${TPCC_THREADS_BUILD_SCHEMA:-2}

#MSSQL 
MAX_SERV=${MAX_SERV:-29490} #this value should be 90% of system memory. Value is in MB
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, given 
  # a TEST_CONFIG yaml configuration. See doc/user-guide/executing-workload/ctest.md for details. 
. "$DIR/../../script/overwrite.sh"

WORKLOAD_PARAMS=(WIN_VER SQL_VER TPCC_NUM_WAREHOUSES TPCC_HAMMER_NUM_VIRTUAL_USERS TPCC_MINUTES_OF_RAMPUP TPCC_MINUTES_OF_DURATION \
TPCC_TOTAL_ITERATIONS TPCC_RUNTIMER_SECONDS TPCC_WAIT_COMPLETE_MILLSECONDS TPCC_THREADS_BUILD_SCHEMA MAX_SERV)


EVENT_TRACE_PARAMS="roi,Taking start Transaction Count,Taking end Transaction Count"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"


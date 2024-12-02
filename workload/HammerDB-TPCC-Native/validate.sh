#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload arguments
# mssql arguments
HOSTOS_VER=${1:-"windows2016"}
SERVER_VER=${2:-"mysql8033"}

# Postgresql arguments
PG_SHARED_BUFFERS=${PG_SHARED_BUFFERS:-8}

# MySQL arguments
MYSQL_INNODB_BUFFER_POOL_SIZE=${MYSQL_INNODB_BUFFER_POOL_SIZE:-8}

# HammerDB arguments
TPCC_NUM_WAREHOUSES=${TPCC_NUM_WAREHOUSES:-100}
TPCC_HAMMER_NUM_VIRTUAL_USERS=${TPCC_HAMMER_NUM_VIRTUAL_USERS:-16}
TPCC_MINUTES_OF_RAMPUP=${TPCC_MINUTES_OF_RAMPUP:-2}
TPCC_MINUTES_OF_DURATION=${TPCC_MINUTES_OF_DURATION:-5}
TPCC_TOTAL_ITERATIONS=${TPCC_TOTAL_ITERATIONS:-10000000}
TPCC_RUNTIMER_SECONDS=${TPCC_RUNTIMER_SECONDS:-600}
TPCC_WAIT_COMPLETE_MILLSECONDS=${TPCC_WAIT_COMPLETE_MILLSECONDS:-5000}
TPCC_THREADS_BUILD_SCHEMA=${TPCC_THREADS_BUILD_SCHEMA:-8}

if [[ "${TESTCASE}" =~ ^test.*_gated$ ]]; then
  PG_SHARED_BUFFERS=2
  MYSQL_INNODB_BUFFER_POOL_SIZE=2
  TPCC_NUM_WAREHOUSES=10
  TPCC_HAMMER_NUM_VIRTUAL_USERS=2
  TPCC_MINUTES_OF_RAMPUP=1
  TPCC_MINUTES_OF_DURATION=1
  TPCC_THREADS_BUILD_SCHEMA=2
fi

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, given 
  # a TEST_CONFIG yaml configuration. See doc/user-guide/executing-workload/ctest.md for details. 
. "$DIR/../../script/overwrite.sh"

WORKLOAD_PARAMS=(HOSTOS_VER SERVER_VER TPCC_NUM_WAREHOUSES TPCC_HAMMER_NUM_VIRTUAL_USERS TPCC_MINUTES_OF_RAMPUP TPCC_MINUTES_OF_DURATION \
TPCC_TOTAL_ITERATIONS TPCC_RUNTIMER_SECONDS TPCC_WAIT_COMPLETE_MILLSECONDS TPCC_THREADS_BUILD_SCHEMA PG_SHARED_BUFFERS MYSQL_INNODB_BUFFER_POOL_SIZE)


EVENT_TRACE_PARAMS="roi,Taking start Transaction Count,Taking end Transaction Count"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"


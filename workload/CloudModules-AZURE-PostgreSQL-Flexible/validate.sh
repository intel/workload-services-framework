#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

### workspace
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
# source "$DIR/script/common.sh"

### HammerDB
TPCC_NUM_WAREHOUSES=${TPCC_NUM_WAREHOUSES:-10}
TPCC_THREADS_BUILD_SCHEMA=${TPCC_THREADS_BUILD_SCHEMA:-10}
TPCC_HAMMER_NUM_VIRTUAL_USERS=${TPCC_HAMMER_NUM_VIRTUAL_USERS:-"10_10"}
TPCC_MINUTES_OF_RAMPUP=${TPCC_MINUTES_OF_RAMPUP:-2}
TPCC_RUNTIMER_SECONDS=${TPCC_RUNTIMER_SECONDS:-600}
TPCC_MINUTES_OF_DURATION=${TPCC_MINUTES_OF_DURATION:-5}
TPCC_TOTAL_ITERATIONS=${TPCC_TOTAL_ITERATIONS:-10000000}
TPCC_WAIT_COMPLETE_MILLSECONDS=${TPCC_WAIT_COMPLETE_MILLSECONDS:-5000}

HAMMERDB_KEYS="TPCC_NUM_WAREHOUSES TPCC_THREADS_BUILD_SCHEMA TPCC_HAMMER_NUM_VIRTUAL_USERS TPCC_MINUTES_OF_RAMPUP TPCC_RUNTIMER_SECONDS \
TPCC_MINUTES_OF_DURATION TPCC_TOTAL_ITERATIONS TPCC_WAIT_COMPLETE_MILLSECONDS"

### Logs Setting
source "$DIR/../../script/overwrite.sh"

WORKLOAD_PARAMS=($HAMMERDB_KEYS)

### Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

### Kubernetes Setting
RECONFIG_OPTIONS=""

### Script Setting
source "$DIR/../../script/validate.sh"

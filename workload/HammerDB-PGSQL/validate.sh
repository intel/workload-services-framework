#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload arguments
  # postgres settings
DB_INSTANCE=${DB_INSTANCE:-1}
DB_HOST=${DB_HOST:-localhost}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-trust}
ENABLE_MOUNT_DIR=${ENABLE_MOUNT_DIR:-false}
RUN_SINGLE_NODE=${RUN_SINGLE_NODE:-true}
MULTI_DISK_NUM=${MULTI_DISK_NUM:-1}
  # hammerdb settings
TPCC_NUM_WAREHOUSES=${TPCC_NUM_WAREHOUSES:-100}
TPCC_MINUTES_OF_RAMPUP=${TPCC_MINUTES_OF_RAMPUP:-2}
TPCC_MINUTES_OF_DURATION=${TPCC_MINUTES_OF_DURATION:-5}
TPCC_VU_NUMBER=${TPCC_VU_NUMBER:-16}
TPCC_VU_THREADS=${TPCC_VU_THREADS:-64}
  # numactl settings
SERVER_SOCKET_BIND_NODE=${SERVER_SOCKET_BIND_NODE:-0} # use "0" to start bind from socket 0
CLIENT_SOCKET_BIND_NODE=${CLIENT_SOCKET_BIND_NODE:-0} # use "1" to start bind from socket 1
SERVER_CORES_PI=${SERVER_CORES_PI:-4} # CORES_PI refers to cores per instance:
CLIENT_CORES_PI=${CLIENT_CORES_PI:-4} # CORES refers to physical cores, if HT is on, CORES_PI=4 means 8 logical cores.

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
DOCKER_IMAGE="$DIR/Dockerfile.1.${WORKLOAD//*_/}.hammerdb"

if [[ "$TESTCASE" == *"gated"* ]]; then
  TPCC_NUM_WAREHOUSES=10
  TPCC_MINUTES_OF_RAMPUP=1
  TPCC_MINUTES_OF_DURATION=2
  TPCC_VU_THREADS=2
  TPCC_VU_NUMBER=2
fi

if [[ "$TESTCASE" == *"hugepage_on"* ]]; then
  HUGE_PAGES_STATUS=on
else
  HUGE_PAGES_STATUS=off
fi

# Logs Setting
. "$DIR/../../script/overwrite.sh"

# params displayed on datashboad
WORKLOAD_PARAMS=(DB_INSTANCE MULTI_DISK_NUM TPCC_NUM_WAREHOUSES TPCC_MINUTES_OF_RAMPUP TPCC_MINUTES_OF_DURATION \
TPCC_VU_THREADS TPCC_VU_NUMBER ENABLE_MOUNT_DIR RUN_SINGLE_NODE HUGE_PAGES_STATUS SERVER_CORES_PI CLIENT_CORES_PI \
SERVER_SOCKET_BIND_NODE CLIENT_SOCKET_BIND_NODE)

# params expected to expand in docker deployment
RECONFIG_OPTIONS="-DDB_INSTANCE=$DB_INSTANCE -DMULTI_DISK_NUM=$MULTI_DISK_NUM -DDB_HOST=$DB_HOST -DPOSTGRES_PASSWORD=$POSTGRES_PASSWORD \
-DTPCC_NUM_WAREHOUSES=$TPCC_NUM_WAREHOUSES -DTPCC_MINUTES_OF_RAMPUP=$TPCC_MINUTES_OF_RAMPUP -DTPCC_MINUTES_OF_DURATION=$TPCC_MINUTES_OF_DURATION \
-DTPCC_VU_THREADS=$TPCC_VU_THREADS -DTPCC_VU_NUMBER=$TPCC_VU_NUMBER -DENABLE_MOUNT_DIR=$ENABLE_MOUNT_DIR -DRUN_SINGLE_NODE=$RUN_SINGLE_NODE \
-DMOUNT_DIR=$MOUNT_DIR -DHUGE_PAGES_STATUS=$HUGE_PAGES_STATUS -DSERVER_CORES_PI=$SERVER_CORES_PI -DCLIENT_CORES_PI=$CLIENT_CORES_PI \
-DSERVER_SOCKET_BIND_NODE=$SERVER_SOCKET_BIND_NODE -DCLIENT_SOCKET_BIND_NODE=$CLIENT_SOCKET_BIND_NODE"

# job name of execution to be traced 
JOB_FILTER="job-name="
for jobid in $(seq 0 $(($DB_INSTANCE-1)) ); do
    JOB_FILTER="${JOB_FILTER}benchmark-${jobid},"
done;
JOB_FILTER=${JOB_FILTER::-1}

# Trace parameters
EVENT_TRACE_PARAMS="roi,Taking start Transaction Count,Taking end Transaction Count"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"



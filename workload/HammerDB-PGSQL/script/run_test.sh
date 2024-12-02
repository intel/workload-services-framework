#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

echo "sleep 30s to wait for server"
sleep 30

if [ -n "$WORKER_0_HOST" ]; then
    echo "replace default db host"
    DB_HOST=$WORKER_0_HOST
fi

# check connection to postgres server
echo "##### $DB_HOST $DB_PORT"
counter=0
until ((counter >= ${TPCC_INIT_MAX_WAIT_SECONDS:-5})); do
    nc -z -w5 $DB_HOST $DB_PORT
    if [ $? -eq 0 ]; then
        let counter=counter+1
    else
        echo "database service connection is unstable, retry"
        counter=0
    fi
    sleep 1
done
echo "Database connection is stable for $counter seconds"

# create tcl benchmark script
/create_tcl.sh

# build schema & start benchmark
source /create_mapping.sh
if [ -n "$WORKER_0_HOST" ]; then # 2 nodes scenario
    if [ "$CLIENT_SOCKET_BIND_NODE" -eq 0 ]; then
        start_tid=0
    elif [ "$CLIENT_SOCKET_BIND_NODE" -eq 1 ]; then
        start_tid=$cores_per_socket
    else
        echo "Please set valid CLIENT_SOCKET_BIND_NODE, either 0 or 1"
        exit 1
    fi
else # 1 node scenario
    start_tid=$cores_per_socket
fi
instance_id=$DB_INDEX
core_mappings $start_tid $instance_id $CLIENT_CORES_PI
NUMACTL_OPTIONS="numactl --cpunodebind=$numa_id --membind=$numa_id --physcpubind=$instance_cores"
echo "NUMACTL_OPTIONS for hammerdb instance $instance_id: $NUMACTL_OPTIONS"

cd ${HAMMERDB_INSTALL_DIR}
echo "===Stage 1: Build schema started==="
start=$(date +%s)
$NUMACTL_OPTIONS ./hammerdbcli auto ${TPCC_TCL_SCRIPT_PATH}/build_schema.tcl
end=$(date +%s)
echo "===Stage 1: Build schema finished spent $(( end - start )) seconds"

echo "===Stage 2: Run timer started"
start=$(date +%s)
$NUMACTL_OPTIONS ./hammerdbcli auto ${TPCC_TCL_SCRIPT_PATH}/run_timer.tcl
end=$(date +%s)
echo "===Stage 2: Run timer finished in $(( end - start )) seconds"

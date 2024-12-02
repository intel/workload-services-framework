#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function buildschema_postgresql() {
    cat >"${TPCC_TCL_SCRIPT_PATH}/build_schema.tcl"<<EOF
#!/bin/tclsh

puts "SETTING CONFIGURATION"
dbset db pg
dbset bm TPC-C
diset connection pg_host $DB_HOST
diset connection pg_port $DB_PORT
diset tpcc pg_count_ware $TPCC_NUM_WAREHOUSES
diset tpcc pg_num_vu 8
diset tpcc pg_superuser postgres
diset tpcc pg_superuserpass $POSTGRES_PASSWORD
diset tpcc pg_storedprocs false
diset tpcc pg_raiseerror  true
vuset logtotemp 1
vuset unique 1
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
EOF
}

function runhammer_postgresql() {
    cat >"${TPCC_TCL_SCRIPT_PATH}/run_timer.tcl"<<EOF
#!/bin/tclsh

puts "SETTING CONFIGURATION"
dbset db pg
diset connection pg_host $DB_HOST
diset connection pg_port $DB_PORT
diset tpcc pg_superuser postgres
diset tpcc pg_vacuum true
diset tpcc pg_driver timed
diset tpcc pg_rampup $TPCC_MINUTES_OF_RAMPUP
diset tpcc pg_duration $TPCC_MINUTES_OF_DURATION
diset tpcc pg_storedprocs false
diset tpcc pg_raiseerror  true
diset tpcc pg_count_ware $TPCC_NUM_WAREHOUSES
diset tpcc pg_num_vu $TPCC_VU_NUMBER
vuset logtotemp 1
vuset unique 1
loadscript

puts "TEST STARTED"
vuset vu $TPCC_VU_THREADS
vucreate
vurun
runtimer 300
vudestroy
tcstop
puts "TEST COMPLETE"
EOF
}

if [[ ! -d "$TPCC_TCL_SCRIPT_PATH" ]]; then
    mkdir -p "$TPCC_TCL_SCRIPT_PATH"
fi

if [ -n $WORKER_0_HOST ]; then
    echo "replace default db host"
    DB_HOST=$WORKER_0_HOST
fi

buildschema_postgresql
runhammer_postgresql

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function connection_check(){
    host=$1
    port=$2
    counter=0
    until ((counter >= 3)); do
        echo "$host connection are stable for $counter seconds"
        nc -z -w5 $host $port
        if [ $? -eq 0 ]; then
            ((counter++))
        else
            counter=0
        fi
        sleep 1
    done
}

# check the connection to config center
connection_check "config-center" $m_config_center_port

# set job index not from redis because in case of potential job restart it would increase the counter and may try to connect to a not existing mongo server
JOB_INDEX=$JOB_COMPLETION_INDEX
echo "JOB_INDEX is $JOB_INDEX"

HOST="${MONGODB_SERVER}-$(($JOB_INDEX + 27017))"
let PORT=27017+${JOB_INDEX}
echo "start mongodb, connect to [$HOST:$PORT]"

# set work path
cd /usr/src/ycsb/

# check the connection to mongodb
connection_check $HOST $PORT

echo "testcase is :[$test_case]"
echo "CONFIG_CENTER_PORT is :[$m_config_center_port]"
echo "CLIENT_SERVER_PAIR is :[$m_client_server_pair]"
echo "THREADS is :[$m_threads]"
echo "OPERATION_COUNT is :[$m_operationcount]"
echo "RECORD_COUNT is :[$m_recordcount]"
echo "INSERT_START is :[$m_insertstart]"
echo "INSERT_COUNT is :[$m_insertcount]"
echo "INSERT_ORDER is :[$m_insertorder]"
echo "FIELD_COUNT is :[$m_fieldcount]"
echo "FIELD_LENGTH is :[$m_fieldlength]"
echo "MIN_FIELD_LENGTH is :[$m_minfieldlength]"
echo "READ_ALL_FIELDS is :[$m_readallfields]"
echo "WRITE_ALL_FIELDS is :[$m_writeallfields]"
echo "READ_PROPORTION is :[$m_readproportion]"
echo "UPDATE_PROPORTION is :[$m_updateproportion]"
echo "INSERT_PROPORTION is :[$m_insertproportion]"
echo "SCAN_PROPORTION is :[$m_scanproportion]"
echo "READ_MODIFY_WRITE_PROPORTION is :[$m_readmodifywrite_proportion]"
echo "REQUEST_DISTRIBUTION is :[$m_requestdistribution]"
echo "MIN_SCANLENGTH is :[$m_minscanlength]"
echo "MAX_SCANLENGTH is :[$m_maxscanlength]"
echo "SCAN_LENGTH_DISTRIBUTION is :[$m_scanlengthdistribution]"
echo "ZERO_PADDING is :[$m_zeropadding]"
echo "FIELD_NAME_PREFIX is :[$m_fieldnameprefix]"
echo "MEASUREMENT_TYPE is :[$m_measurementtype]"
echo "MAX_EXECUTION_TIME is :[$m_maxexecutiontime]"
echo "JVM_ARGS is :[$m_jvm_args]"
echo "TARGET is :[$m_target]"
echo "TLS_FLAG is :[$m_tls_flag]"
echo "REPLICA_SET is :[$m_replica_set]"

# add non-empty variables to ycsb_params 
ycsb_params="-threads $m_threads"
for var in "m_operationcount" "m_recordcount" "m_fieldcount" "m_fieldlength" "m_minfieldlength" "m_readallfields" "m_writeallfields" "m_readproportion" "m_updateproportion" "m_insertproportion" "m_scanproportion" "m_readmodifywrite_proportion" "m_requestdistribution" "m_minscanlength" "m_maxscanlength" "m_scanlengthdistribution" "m_zeropadding" "m_fieldnameprefix" "m_measurementtype" "m_insertorder"; do
    if [ ! -z $(eval echo "\$$var") ]; then
        suffix_var="${var#m_}"
        ycsb_params="$ycsb_params -p $suffix_var=$(eval echo "\$$var")"
    fi
done

# enable tls
if [ $m_tls_flag -eq 0 ]
then
	ycsb_params="$ycsb_params -p mongodb.url=mongodb://${HOST}:${PORT}/ycsb?maxPoolSize=1500"
else
    # read tls key from redis
	until redis-cli -h config-center -p $m_config_center_port --raw HGET moncaone-${PORT} pem_binary  > /jdk/jdk-version/lib/security/moncaone-${PORT}.pem; do
		echo "moncaone-${PORT}.pem is not in the redis"
	done
	# rm older version will generate error
	# rm /jdk/jdk-version/lib/security/cacerts -f 
	keytool -import -noprompt -trustcacerts -alias cacert -storepass changeit -keystore /jdk/jdk-version/lib/security/cacerts -file /jdk/jdk-version/lib/security/moncaone-${PORT}.pem
    # update the ycsb_params
	ycsb_params="$ycsb_params -p mongodb.url=mongodb://${HOST}:${PORT}/ycsb?ssl=true&maxPoolSize=1500"
fi

# once connection is stable, upgrade db to replica set if enabled
if [[ "$m_replica_set" == "true" ]]; then
    /usr/bin/python /usr/src/initiate_rs.py
fi

#  numa policy for ycsb
## for multi-node scenario, it is recommended not to set numa policy;
## customize numa ploicy for ycsb bu setting CUSTOMER_NUMAOPT_CLIENT;
## for single node scenario, it is recommended bound ycsb to differnet socket with mongodb
NUMA_POLICY=""
if [[ -n $m_customer_numaopt_client ]]; then
    NUMA_POLICY=$m_customer_numaopt_client
elif [[ $m_run_single_node == "true" ]] || [ $m_client_count -eq 0 ] && [[ $m_numactl_option -eq 2 || $m_numactl_option -eq 3 || $m_numactl_option -eq 4 ]]; then
    if [[ -n "$m_ycsb_cores" ]]; then
        NUMA_POLICY="numactl --physcpubind=${m_ycsb_cores} --localalloc"
    else
        node_id=${m_select_numa_node}
        NUMA_POLICY="numactl --cpunodebind=!${node_id} --localalloc"
    fi
fi
echo "NUMA_POLICY: ${NUMA_POLICY}"

# set ycsb parameters for load phase
ycsb_params_loadphase="$ycsb_params"
echo "ycsb loadphase parameters: ${ycsb_params_loadphase}"

echo "[LOAD_PHASE]"
${NUMA_POLICY} ./bin/ycsb load mongodb -P workloads/$workload_file -s ${ycsb_params}
LOAD_PHASE_RC=$?

if [ $LOAD_PHASE_RC -eq 0 ]; then
    echo "YCSB load succeeded"
    redis-cli -h config-center -p $m_config_center_port incr populate_index
    until redis-cli -h config-center -p $m_config_center_port set benchmark$JOB_INDEX success; do
        echo "register benchmark$JOB_INDEX to config-center after success"
    done
else
    echo "YCSB load failed"
    until redis-cli -h config-center -p $m_config_center_port set benchmark$JOB_INDEX error; do
        echo "register benchmark$JOB_INDEX to config-center after failure"
    done
    exit $LOAD_PHASE_RC
fi

# register load phase finish signal to config center
RESULT=$(redis-cli -h config-center -p $m_config_center_port GET benchmark$JOB_INDEX)
if [ "$RESULT" = "success" ]; then
    echo "Benchmark$JOB_INDEX successful loads out of $m_client_server_pair in total"
else
    echo "Load phase error detected on benchmark$JOB_INDEX! Exiting with failure."
    exit 1
fi

until test $(redis-cli -h config-center -p $m_config_center_port GET populate_index) -eq $m_client_server_pair; do
    sleep 0.2
done

# sleep some time for split load phase and run phase on time
echo "Sleep 30s for load and run phase split in collectd"
sleep 30 

# set ycsb parameters for run phase
ycsb_params_runphase="$ycsb_params"
for var in "m_insertstart" "m_insertcount" "m_maxexecutiontime" "m_target" "m_jvm_args"; do
    if [ ! -z $(eval echo "\$$var") ]; then
        suffix_var="${var#m_}"
        if [[ $suffix_var == "target" ]]; then
            suffix_var=$(echo "$suffix_var" | sed 's/_/-/g')
            ycsb_params_runphase="$ycsb_params_runphase -$suffix_var $(eval echo "\$$var")"
        elif [[ $suffix_var == "jvm_args" ]]; then
            suffix_var=$(echo "$suffix_var" | sed 's/_/-/g')
            ycsb_params_runphase="$ycsb_params_runphase -$suffix_var=$(eval echo "\$$var")"
        else
            ycsb_params_runphase="$ycsb_params_runphase -p $suffix_var=$(eval echo "\$$var")"
        fi
    fi
done
echo "ycsb runphase parameters: ${ycsb_params_runphase}"

echo "[RUN_PHASE]"
${NUMA_POLICY} ./bin/ycsb run mongodb -P workloads/$workload_file -s ${ycsb_params_runphase}
RUN_PHASE_RC=$?
echo "benchmark-finish"

if [ $RUN_PHASE_RC -eq 0 ]; then
    echo "YCSB run succeeded"
else
    echo "YCSB run failed"
fi

# Collect DB table information
/usr/bin/python /usr/src/collect_dbtable_info.py $HOST $PORT

# Download MongoDB server logs from redis
redis-cli -h config-center -p $m_config_center_port get mongodb-$PORT-log >> /usr/src/mongodb.log

exit $RUN_PHASE_RC

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

echo "preparing >>>"
source prepare_ycsb.sh

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

# get job index from config center
let JOB_INDEX=$(redis-cli -h config-center -p $m_config_center_port incr job_index)-1
echo "JOB_INDEX is $JOB_INDEX"

HOST="${MONGODB_SERVER}-$(($JOB_INDEX + 27017))"
let PORT=27017+${JOB_INDEX}
echo "start mongdb, connect to [$HOST:$PORT]"

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

echo "[LOAD PHASE]"
${NUMA_POLICY} ./bin/ycsb load mongodb -P workloads/$workload_file -s ${ycsb_params} && {
    until redis-cli -h config-center -p $m_config_center_port set benchmark$JOB_INDEX benchmark$JOB_INDEX; do
        echo "register benchmark$JOB_INDEX to config-center failed. Will continue to try to re-register"
    done
}

# register load phase finish signal to config center
until test $(redis-cli -h config-center -p $m_config_center_port keys benchmark* | wc -l) -eq $m_client_server_pair; do
    echo "there is $(redis-cli -h config-center -p $m_config_center_port keys benchmark* | wc -l) load phase process have finished"
    sleep 0.2
done
# sleep some time for split load phase and run phase on time
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

echo "[RUN PHASE]"
${NUMA_POLICY} ./bin/ycsb run mongodb -P workloads/$workload_file -s ${ycsb_params_runphase}

echo "benchmark-finish"

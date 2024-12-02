#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
redis_counter=0
config_port=${MEMTIER_CONFIG_CENTER_PORT}
until ((redis_counter >= 3)); do
    echo "Config center connection are stable for $redis_counter seconds"
    nc -z -w5 redis-config-center $config_port
    if [ $? -eq 0 ]; then
        ((redis_counter++))
    else
        redis_counter=0
    fi
    sleep 1
done
#### server_ip and port
server_ip=${MEMTIER_SERVER_IP}
let JOB_INDEX=$(redis-cli -h redis-config-center -p $config_port incr job_index)-1
let port=${MEMTIER_STARTPORT}+${JOB_INDEX}
memtier_options=""
memtier_requests=${MEMTIER_REQUESTS:-0}
memtier_test_time=${MEMTIER_TEST_TIME:-300}
memtier_data_size=${MEMTIER_DATA_SIZE:-4096}
memtier_pipeline=${MEMTIER_PIPELINE:-1}
memtier_clients=${MEMTIER_CLIENTS:-8}
memtier_threads=${MEMTIER_THREADS:-2}
memtier_ratio=${MEMTIER_RATIO:-"1:10"}
memtier_key_minimum=${MEMTIER_KEY_MINUMUM:-1}
memtier_key_maximum=${MEMTIER_KEY_MAXIMUM:-10000000}
memtier_run_key_pattern=${MEMTIER_KEY_PATTERN:-"R:R"}   
memtier_load_key_pattern=${MEMTIER_LOAD_KEY_PATTERN:-"P:P"}
memtier_randomize=${MEMTIER_RANDOMIZE:-""}
memtier_distinct_client_seed=${MEMTIER_DISTINCT_CLIENT_SEED:-""}
memtier_run_count=${MEMTIER_RUN_COUNT:-1}

function config_memtier() {
    memtier_options="--server $server_ip --port $port --ratio=$memtier_ratio \
    --pipeline=$memtier_pipeline --key-pattern=$memtier_run_key_pattern --key-minimum=$memtier_key_minimum \
    --key-maximum=$memtier_key_maximum --clients=$memtier_clients --threads=$memtier_threads \
    --run-count=$memtier_run_count --out-file=memtier-bench${JOB_INDEX}.log"
    
    if [[ $memtier_data_size == *":"* ]]; then
        echo "using data-size-list to define data size"
        memtier_options="${memtier_options} --data-size-list=$memtier_data_size"
    else
        memtier_options="${memtier_options} --data-size=$memtier_data_size"
    fi

    if [[ "$memtier_requests" == "0" ]]
    then 
        echo "test specified by memtier_test_time"
        memtier_options="${memtier_options} --test-time=$memtier_test_time"
    else
        echo "test specified by memtier_requests"
        memtier_options="${memtier_options} --requests=$memtier_requests"
    fi

    if [[ "$memtier_distinct_client_seed" == "true" ]]
    then
        memtier_options="${memtier_options} --distinct-client-seed"
    fi

    if [[ "$memtier_randomize" == "true" ]]
    then
        memtier_options="${memtier_options} --randomize"
    fi

    echo "Memtier Run configuration:" > ./test-config
    echo "    $memtier_options" >> ./test-config
}

function populate() {
    memtier_benchmark -s $server_ip -p $port --key-maximum=$memtier_key_maximum -n allkeys -d $memtier_data_size --key-pattern=$memtier_load_key_pattern --ratio=1:0 -c 4 --threads=8 --pipeline=64 --out-file=memtier-populate${JOB_INDEX}.log > /dev/null 2>&1
}

config_memtier
##### test networks
redis_counter=0
until ((redis_counter >= 3)); do
    echo "Redis service connection are stable for $redis_counter seconds"
    nc -z -w5 ${server_ip} $port
    if [ $? -eq 0 ]; then
        ((redis_counter++))
    else
        redis_counter=0
    fi
    sleep 1
done

#### get config
echo "Redis-server configuration:" >> ./test-config
redis-cli -h ${server_ip} -p $port CONFIG GET \* >> ./test-config

populate

until redis-cli -h redis-config-center -p $config_port set benchmark$JOB_INDEX benchmark$JOB_INDEX; do
    echo "register benchmark$JOB_INDEX to redis-config-center failed. Will continue to try to re-register"
done


until test $(redis-cli -h redis-config-center -p $config_port keys benchmark* | wc -l) -eq $r_client_server_pair; do
    echo "there is $(redis-cli -h redis-config-center -p $config_port keys benchmark* | wc -l) load phase process have finished"
    sleep 0.2
done
# Execute benchmark
sleep 30

### emon trace begin here
echo "start region of interest"

echo "############redis-$port Begins testing#############"

total_core=$(nproc)
total_numa=$(lscpu | awk '/^NUMA node\(s\)/{print $3'})
core_pernuma=$(($total_core/$total_numa))
let redis_instance_index=$JOB_INDEX+$start_numa_node*$core_pernuma
if [[ $RUN_SINGLE_NODE == "true" ]]; then
    if [ $r_client_server_pair -ge $total_core ]; then
        echo "there is no more cores for memtier client"
    fi

    if [[ $redis_numactl_strategy == 0 ]]; then
        echo "you are using customerize numactl_options, please make sure your policy is valid"
        MEMTIER_CLIENT_NUMACTL_OPTIONS=$(echo $MEMTIER_CLIENT_NUMACTL_OPTIONS | sed 's/+/ /g')
        MEMTIER_CLIENT_NUMACTL_OPTIONS="numactl $MEMTIER_CLIENT_NUMACTL_OPTIONS"
    elif [[ $redis_numactl_strategy == 1 ]]; then
        cpuset=$(cat /sys/devices/system/cpu/cpu${redis_instance_index}/topology/thread_siblings_list)
        for((i=1;i<$r_client_server_pair;i++));  
        do  
            tmp=$(($redis_instance_index+$i))
            tmpcpuset=$(cat /sys/devices/system/cpu/cpu${tmp}/topology/thread_siblings_list)
            cpuset="$cpuset,$tmpcpuset"
        done
        MEMTIER_CLIENT_NUMACTL_OPTIONS="numactl --physcpubind=!$cpuset"
    elif [[ $redis_numactl_strategy == 2 ]]; then
        cpuset="${redis_instance_index}"
        for((i=1;i<$r_client_server_pair;i++));
        do
            tmp=$(($redis_instance_index+$i))
            cpuset="$cpuset,$tmp"
        done
        MEMTIER_CLIENT_NUMACTL_OPTIONS="numactl --physcpubind=!$cpuset"
    elif [[ $redis_numactl_strategy == 3 ]]; then
        MEMTIER_CLIENT_NUMACTL_OPTIONS="numactl --cpunodebind=!${start_numa_node}"
    else
        echo "error: redis_numactl_strategy invalid"
    fi 
else
    echo "multinode"
fi
$MEMTIER_CLIENT_NUMACTL_OPTIONS memtier_benchmark ${memtier_options}

### check log here
cat memtier-bench* | grep Total
if [[ $? != 0 ]];
then
    echo "Do not run test correctly"
    exit 1
fi
echo "############redis-$port completed testing##########"

### emon trace end here
echo "end region of interest"


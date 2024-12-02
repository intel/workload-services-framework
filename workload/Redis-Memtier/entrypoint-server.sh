#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

total_core=$(nproc)
total_numa=$(lscpu | awk '/^NUMA node\(s\)/{print $3'})
core_pernuma=$(($total_core/$total_numa))
lscpu -p=CPU,NODE|sed -e '/^#/d' > /redis/cpu_numa_map
lscpu -p=CPU,NODE|sed -e '/^#/d' | sort -n -t ',' -k2 -k1 > /redis/sorted_cpu_numa_map
redis_config_file="/redis/redis-conf/redis_conf.conf"
redis_server="/build/redis-${redis_version}/src/redis-server"
server_cpu_numa_map='/redis/cpu_numa_map'
sorted_server_cpu_numa_map='/redis/sorted_cpu_numa_map'

function memory_size_chick() {
    ##### More Action Needed to be done #####
    # Memory requirement is (64MB + ((15 / 10000) * requests * data_size kB)) per instance
    memtier_requests=$1
    memtier_data_size=$2
    mem_needed=$(((64000 + ($memtier_requests * $memtier_data_size * 15 / 10000)) * $redis_instance_number))
    mem_free=$(grep '^MemFree' /proc/meminfo | awk '{print $2}')
    echo "Checking memory... Need ${mem_needed} kB, have ${mem_free} kB."
    if [ $mem_needed -gt $mem_free ]
    then
        echo "WARNING: may have insufficient memory for test configuration."
    fi

    if [ $memtier_requests -ne $memtier_key_maximum ]
    then
        echo "WARNING: MEMTIER_REQUESTS not equal to MEMTIER_KEY_MAXIMUM."
    fi
}

function customize_redis_conf() {
    ## specify the redis configuration
    redis_config_file=$1
    redis_server_io_threads=$2
    redis_server_io_threads_do_reads=$3
    redis_persistence_policy=$4
    redis_server_io_threads_cpu_affinity=$5
    redis_eviction_policy=$6
    # THREADED I/O
    [[ $redis_server_io_threads -ne 0 ]] && {
        sed -i "s/# io-threads 4/io-threads ${redis_server_io_threads}/g" $redis_config_file
    }
    [ "$redis_server_io_threads_do_reads" == "true" ] && {
        sed -i "s/# io-threads-do-reads no/io-threads-do-reads yes/g" $redis_config_file
    }
    # PERSISTENCE POLICY
    if [[ "${redis_persistence_policy}" == "false" ]];then
        sed -i 's/# save ""/save ""/g' $redis_config_file
    else
        if [[ "${redis_persistence_policy}" == "AOF" ]];then
            sed -i 's/# save ""/save ""/g' $redis_config_file
            sed -i "s/appendonly no/appendonly yes/g" $redis_config_file
            sed -i "s/appendfsync everysec/appendonly ${redis_appendfsync_mode}/g" $redis_config_file
        elif [[ "${redis_persistence_policy}" == "RDB" ]];then
            sed -i "s/# save 3600 1/save ${redis_rdb_seconds} ${redis_rdb_changes}/g" $redis_config_file
        else
            echo "nothing to do with persistence configuration"
        fi
    fi
    # ACTIVE DEFRAGMENTATION
    if [[ "${redis_server_io_threads_cpu_affinity}" == "false" ]];then
        echo "nothing to do with redis server/io threads cpu affinity"
    else
        echo "set cpu affinity"
        sed -i "s/# server_cpulist 0-7:2/server_cpulist ${redis_server_io_threads_cpu_affinity}/g" $redis_config_file
    fi
    # MEMORY MANAGEMENT
    if [[ "${redis_eviction_policy}" == "false" ]];then
        echo "nothing to do with redis eviction policy"
    else
        sed -i "s/# maxmemory-policy noeviction/maxmemory-policy ${redis_eviction_policy}/g" $redis_config_file
    fi
}

function numa_strategy() {
    redis_instance_index=$1
    cpu_numa_map=$2
    sorted_cpu_numa_map=$3
    redis_numactl_strategy=$4

    if [[ $redis_numactl_strategy == 0 ]]; then
        echo "you are using customerize numactl_options, please make sure your policy is valid"
        REDIS_SERVER_NUMACTL_OPTIONS=$(echo $REDIS_SERVER_NUMACTL_OPTIONS | sed 's/+/ /g')
        REDIS_SERVER_NUMACTL_OPTIONS="numactl $REDIS_SERVER_NUMACTL_OPTIONS"
    elif [[ $redis_numactl_strategy == 1 ]]; then
        echo "each instance will be bind with a specific physical core and their logical cores "
        core_index1=$(cat $sorted_cpu_numa_map | awk "NR==$(($redis_instance_index+1))" | awk '{split($0,a,","); print a[1]}')
        cpuset=$(cat /sys/devices/system/cpu/cpu${core_index1}/topology/thread_siblings_list)
        node_of_core_index1=$(cat $sorted_cpu_numa_map | awk "NR==$(($redis_instance_index+1))" | awk '{split($0,a,","); print a[2]}')
        REDIS_SERVER_NUMACTL_OPTIONS="numactl --physcpubind=$cpuset --membind=$node_of_core_index1"
        echo "REDIS_SERVER_NUMACTL_OPTIONS=${REDIS_SERVER_NUMACTL_OPTIONS}"
    elif [[ $redis_numactl_strategy == 2 || $redis_numactl_strategy == 3 ]]; then
        echo "each instance will be bind with a specific physical core "
        core_index2=$(cat $sorted_cpu_numa_map | awk "NR==$(($redis_instance_index+1))" | awk '{split($0,a,","); print a[1]}')
        node_of_core_index=$(cat $sorted_cpu_numa_map | awk "NR==$(($redis_instance_index+1))" | awk '{split($0,a,","); print a[2]}')
        REDIS_SERVER_NUMACTL_OPTIONS="numactl --physcpubind=$core_index2 --membind=$node_of_core_index"
        echo "REDIS_SERVER_NUMACTL_OPTIONS=${REDIS_SERVER_NUMACTL_OPTIONS}"
    elif [[ $redis_numactl_strategy == 4 ]]; then
        echo "bind all redis instances to all numanode evenly "
        node_num=$(lscpu | grep "NUMA node(s):" | awk '{print $3}')
        let node_index=${redis_instance_index}%${node_num}
        echo "server ${redis_instance_index} is binded to numa node $node_index"
        REDIS_SERVER_NUMACTL_OPTIONS="numactl --cpunodebind=$node_index --membind=$node_index"
        echo "REDIS_SERVER_NUMACTL_OPTIONS=${REDIS_SERVER_NUMACTL_OPTIONS}"
    else
        echo "Please specify REDIS_NUMACTL_STRATEGY 0 or 1 or 2 or 3 or 4"
    fi
}

if ${RPS_TUNE} ; then
    . /redis/network_tune.sh
fi

# memory_size_chick $memtier_requests $memtier_data_size
for ((i=0;i<$redis_instance_number;i++))
do
    let redis_port_index=$redis_native_transport_port+$i
    let redis_instance_index=$i+$start_numa_node*$core_pernuma
    customize_redis_conf $redis_config_file $redis_server_io_threads $redis_server_io_threads_do_reads $redis_persistence_policy $redis_server_io_threads_cpu_affinity $redis_eviction_policy
    numa_strategy $redis_instance_index $server_cpu_numa_map $sorted_server_cpu_numa_map $redis_numactl_strategy
    $REDIS_SERVER_NUMACTL_OPTIONS $redis_server $redis_config_file --port $redis_port_index &
done

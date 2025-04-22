#!/usr/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

REDIS_VERSION=${REDIS_VERSION}
REDIS_NATIVE_TRANSPORT_PORT=${REDIS_NATIVE_TRANSPORT_PORT}
INSTANCE_NUM=${INSTANCE_NUM}
REDIS_NUMACTL_STRATEGY=${REDIS_NUMACTL_STRATEGY}
NUMA_NODE_FOR_REDIS_SERVER=${NUMA_NODE_FOR_REDIS_SERVER}
REDIS_SERVER_IO_THREADS=${REDIS_SERVER_IO_THREADS}
REDIS_SERVER_IO_THREADS_DO_READS=${REDIS_SERVER_IO_THREADS_DO_READS}
REDIS_PERSISTENCE_POLICY=${REDIS_PERSISTENCE_POLICY}
REDIS_SERVER_IO_THREADS_CPU_AFFINITY=${REDIS_SERVER_IO_THREADS_CPU_AFFINITY}
REDIS_EVICTION_POLICY=${REDIS_EVICTION_POLICY}

total_core=$(nproc)
total_numa=$(lscpu | awk '/^NUMA node\(s\)/{print $3'})
core_pernuma=$(($total_core/$total_numa))
lscpu -p=CPU,NODE|sed -e '/^#/d' | sort -n -t ',' -k2 -k1 > /redis/sorted_cpu_numa_map
redis_config_file="/redis/redis-conf/redis_conf.conf"
redis_server="/home/redis-${REDIS_VERSION}/src/redis-server"
sorted_server_cpu_numa_map='/redis/sorted_cpu_numa_map'

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
    sorted_cpu_numa_map=$2

  case $REDIS_NUMACTL_STRATEGY in
    0)
      REDIS_SERVER_NUMACTL_OPTIONS=""
      ;;
    1)
      echo "each instance will be bind with a specific physical core "
      core_index2=$(cat $sorted_cpu_numa_map | awk "NR==$(($redis_instance_index+1))" | awk '{split($0,a,","); print a[1]}')
      node_of_core_index=$(cat $sorted_cpu_numa_map | awk "NR==$(($redis_instance_index+1))" | awk '{split($0,a,","); print a[2]}')
      REDIS_SERVER_NUMACTL_OPTIONS="numactl --physcpubind=$core_index2 --localalloc"
      echo "REDIS_SERVER_NUMACTL_OPTIONS=${REDIS_SERVER_NUMACTL_OPTIONS}"
      ;;
    2)
      cpuset=$(cat /sys/devices/system/cpu/cpu${redis_instance_index}/topology/thread_siblings_list)
      if [[ "$cpuset" == *","* ]]; then
        echo "SMT-ON MODE" 
        echo "cpuset $cpuset portnum: $newport"
        REDIS_SERVER_NUMACTL_OPTIONS="numactl --physcpubind=${cpuset} --localalloc"
      else
        echo "SMT-OFF MODE"
        let core_index=$redis_instance_index*2
        core_index_next=$(( $core_index+1 ))
        new_cpuset="${core_index},${core_index_next}"
        echo "cpuset $new_cpuset portnum: $newport"
        REDIS_SERVER_NUMACTL_OPTIONS="numactl --physcpubind=${new_cpuset} --localalloc"
      fi
      ;;
    *)
      REDIS_SERVER_NUMACTL_OPTIONS=""
      ;;
  esac

}

for ((i=0;i<$INSTANCE_NUM;i++))
do
    let redis_port_index=$REDIS_NATIVE_TRANSPORT_PORT+$i
    let redis_instance_index=$i+$NUMA_NODE_FOR_REDIS_SERVER*$core_pernuma
    customize_redis_conf $redis_config_file $REDIS_SERVER_IO_THREADS $REDIS_SERVER_IO_THREADS_DO_READS $REDIS_PERSISTENCE_POLICY $REDIS_SERVER_IO_THREADS_CPU_AFFINITY $REDIS_EVICTION_POLICY
    numa_strategy $redis_instance_index $sorted_server_cpu_numa_map
    $REDIS_SERVER_NUMACTL_OPTIONS $redis_server $redis_config_file --port $redis_port_index &
done
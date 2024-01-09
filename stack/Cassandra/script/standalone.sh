#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -e

#env deault value
cassandra_cluster_name=${cassandra_cluster_name:-cassandra standalone}
cassandra_native_transport_port=${cassandra_native_transport_port:-9042}
cassandra_storage_port=${cassandra_storage_port:-7000}
cassandra_JMX_port=${cassandra_JMX_port:-7199}
cassandra_server_addr=${cassandra_server_addr:-localhost}
cassandra_rpc_address=${cassandra_rpc_address:-${cassandra_server_addr}}
cassandra_broadcast_address=${cassandra_broadcast_address:-${cassandra_server_addr}}
cassandra_broadcast_rpc_address=${cassandra_broadcast_rpc_address:-${cassandra_server_addr}}
cassandra_seeds=${cassandra_seeds:-${cassandra_server_addr}}
cassandra_concurrent_reads=${cassandra_concurrent_reads:-8}
cassandra_concurrent_writes=${cassandra_concurrent_writes:-24}
cassandra_compaction_throughput_mb_per_sec=${cassandra_compaction_throughput_mb_per_sec:-16}
cassandra_cross_node_timeout=${cassandra_cross_node_timeout:-false}
cassandra_dynamic_snitch_badness_threshold=${cassandra_dynamic_snitch_badness_threshold:-0.1}
cassandra_gc_warn_threshold_in_ms=${cassandra_gc_warn_threshold_in_ms:-1000}
cassandra_server_instance_num=${cassandra_server_instance_num:-1}
cassandra_numactl_enable=${cassandra_numactl_enable:-false}
numa_options=${numa_options:-}
cassandra_slow_query_log_timeout_in_ms=${cassandra_slow_query_log_timeout_in_ms:-60000}
CASSANDRA_JVM_HEAP_SIZE=${CASSANDRA_JVM_HEAP_SIZE:-12}
CASSANDRA_JVM_GC_TYPE=${CASSANDRA_JVM_GC_TYPE:-+UseG1GC}
HOST_NETWORK=${HOST_NETWORK:-false}
RPS_TUNE=${RPS_TUNE:-false}

#set cassandra parameter in cassandra.yaml, no related with instance num
set_cassandra_param() {
    sed_in_place "$CASSANDRA_CONF/cassandra.yaml" \
        -r 's/(- seeds:).*/\1 "'"$cassandra_seeds"'"/'

    for yaml in \
        cluster_name \
        native_transport_port \
        rpc_address \
        broadcast_address \
        broadcast_rpc_address \
        num_tokens \
        concurrent_reads \
        concurrent_writes \
        compaction_throughput_mb_per_sec \
        cross_node_timeout \
        dynamic_snitch_badness_threshold \
        gc_warn_threshold_in_ms \
        slow_query_log_timeout_in_ms \
    ; do
        var="cassandra_${yaml}"
        val="${!var}"	
        if [ "$val" ]; then
            sed_in_place "$CASSANDRA_CONF/cassandra.yaml" \
                -r 's/^(# )?('"$yaml"':).*/\2 '"$val"'/'
        fi
    done

    for rackdc in dc rack; do
        var="cassandra_${rackdc}"
		val="${!var}"
        if [ "$val" ]; then
            sed_in_place "$CASSANDRA_CONF/cassandra-rackdc.properties" \
                -r 's/^('"$rackdc"'=).*/\1 '"$val"'/'
        fi
    done
}

numa_node_num=1
get_numa_node_num() {    
    numa_node_num=`numactl --hardware | grep cpus | wc -l`      
}

#Set JVM parameters
set_JVM_param() {
    
    free_memory=`cat /proc/meminfo | egrep '^MemFree' | awk '{printf "%d\n", $2/1024/1024}'`
    instance_num=${cassandra_server_instance_num}
    if  ${cassandra_numactl_enable:-true}; then
        get_numa_node_num
        instance_per_numa=$(($instance_num > $numa_node_num ? $instance_num / $numa_node_num : 1)) 
    else
        numa_node_num=1
        instance_per_numa=$instance_num
    fi 
         
    assignable_size=$((8 * $free_memory / 10 / $numa_node_num / $instance_per_numa))
    heap_size=$(($CASSANDRA_JVM_HEAP_SIZE < $assignable_size ? $CASSANDRA_JVM_HEAP_SIZE : $assignable_size))
   
    for jvm_conf in \
    -Xms \
    -Xmx \
    ;do
        for arg in "-Xms${heap_size}G" "-Xmx${heap_size}G";
        do        
            if [[ $arg == $jvm_conf*  ]]; then            
                sed_in_place "$CASSANDRA_CONF/jvm11-server.options" \
                    -r 's/^'"$jvm_conf"'.*/'"$arg"'/'
            fi
        done
    done

    #Set JVM GC Type
    jvm_gc_conf_line=`sed -n -e '/'"JVM garbage Settings"'/=' $CASSANDRA_CONF/jvm11-server.options`
    jvm_gc_conf_line=$(($jvm_gc_conf_line + 1))
    sed -i "${jvm_gc_conf_line}c  ${CASSANDRA_JVM_GC_TYPE}" $CASSANDRA_CONF/jvm11-server.options

}

instance_per_node=1
get_instance_per_node() {  
    get_numa_node_num
    instance_num=${cassandra_server_instance_num}   
    instance_per_node=${instance_num}

     #check if instance_num reasonable
    if [ ${numa_node_num} -eq ${instance_num} ] || [ ${numa_node_num} -lt ${instance_num} ]; then    
        instance_per_node=$((${instance_num} / ${numa_node_num}))       
    fi

    if [ ${numa_node_num} -gt ${instance_num} ]; then
        instance_per_node=1
    fi
}

# "sed -i", but without "mv" (which doesn't work on a bind-mounted file, for example)
sed_in_place() {   
    local filename="$1"; shift
    local tempFile
    tempFile="$(mktemp)"
    sed "$@" "$filename" > "$tempFile"
    cat "$tempFile" > "$filename"
    rm "$tempFile"
}

set_instance_param() {   
    #1. cassandra.yaml:
    #     data_file_directories:
    #           - /var/lib/cassandra/data
    #     decommitlog_directory: /var/lib/cassandra/commitlog
    #     commitlog_directory: /cassandra/
    #     saved_caches_directory: /var/lib/cassandra/saved_caches      
    #     native_transport_port: 9042
    #     storage_port: 8000
    #2.cassandra-env.sh:
    #     JMX_PORT="7199"
    #3.jvm11-server.options:
    #     -Dcom.sun.management.jmxremote.port=7199
    index=$1
    base_path=$2
    conf_path="${base_path}/conf"

    #set "data_file_directories:"       
    data_path="    - /$base_path/current_data/$index/data/"
    data_conf_line=`sed -n '/'"data_file_directories:"'/=' $conf_path/cassandra.yaml`
    data_path_line=$(($data_conf_line + 1))
    sed -i "${data_conf_line}c data_file_directories:" $conf_path/cassandra.yaml
    sed -i "${data_path_line}c  $data_path" $conf_path/cassandra.yaml

    #commit log path, default : decommitlog_directory: /var/lib/cassandra/commitlog
    commit_log_path_conf="commitlog_directory: /$base_path/current_data/$index/commitlog"
    conf_line=`sed -n '/'"commitlog_directory:"'/=' $conf_path/cassandra.yaml`
    sed -i "${conf_line}c $commit_log_path_conf" $conf_path/cassandra.yaml

    #saved_caches_directory
    cache_line=`sed -n '/'"saved_caches_directory:"'/=' $conf_path/cassandra.yaml`
    caches_directory="saved_caches_directory: /$base_path/current_data/$index/saved_caches"
    sed -i "${cache_line}c $caches_directory" $conf_path/cassandra.yaml    
    
    #native_transport_port
    native_transport_port=$(($cassandra_native_transport_port+$index))
    sed_in_place "$conf_path/cassandra.yaml" \
        -r 's/^(# )?('"native_transport_port"':).*/\2 '"$native_transport_port"'/'
    
    #storage_port
    storage_port=$(($cassandra_storage_port+$index))
    sed_in_place "$conf_path/cassandra.yaml" \
        -r 's/^(# )?('"storage_port"':).*/\2 '"$storage_port"'/'
    
    #JMX_PORT
    JMX_PORT=$(($cassandra_JMX_port+$index))
    sed_in_place "$conf_path/cassandra-env.sh" \
        -r 's/^(# )?('"JMX_PORT="').*/\2'"$JMX_PORT"'/'
    sed_in_place "$conf_path/jvm11-server.options" \
        -r 's/^(# )?('"-Dcom.sun.management.jmxremote.port="').*/\2'"$JMX_PORT"'/'

}

start_cassandra_instance() {
    index=$1
    node=$2
    cassandra_home="/cassandra/"
    user_name="cassandra$index"
    user_home="/${user_name}"

    #create user for each instance
    useradd -m -d $user_home $user_name -G cassandra

    #copy all cassandra files,real files no softlink
    cp -RL ${cassandra_home}*  $user_home
    chown -R $user_name:$user_name ${user_home}
    
    #configure each instance
    set_instance_param $index $user_home

    export CASSANDRA_HOME="/$user_name" CASSANDRA_CONF="/${user_name}/conf"

    #if (not set $numa_option && $cassandra_numactl_enable==true)  bound to numa node automatically
    if  ${cassandra_numactl_enable:-true}; then
        export NUMACTL_ARGS="-m $node -N $node"
    fi
    #if  numa_option set, bound core regarding  $numa_option
    if [[ ! -z "$numa_options" ]]; then
        export NUMACTL_ARGS=$numa_options
    fi

    #start cassandra, use 'su' no 'su -' to inherite root env
    su $user_name<<EOF     
    nohup ${CASSANDRA_HOME}/bin/cassandra -f > ${CASSANDRA_HOME}/output-start-$node-$index.log &  
EOF
}

host_network_set() {
    if ${HOST_NETWORK} && ${RPS_TUNE} ; then
        . /usr/local/bin/network_tune.sh
    fi
}

#Tune host network
host_network_set

#set parameters which no ralated with instance num
set_cassandra_param
set_JVM_param
#get instance number on each numa node
get_numa_node_num
get_instance_per_node

#set instance parameters and start cassandra instance on each numa node
already_schedled_instance_num=0
for(( node=0; node < $numa_node_num; node++ )); do
    if [ $(($already_schedled_instance_num)) -eq  $(($cassandra_server_instance_num)) ]; then
        break
    fi       
    for(( i=0; i < $instance_per_node; i++ )); do        
        start_cassandra_instance $already_schedled_instance_num $node
        already_schedled_instance_num=$(($already_schedled_instance_num + 1))
        if [ $(($already_schedled_instance_num)) -eq  $(($cassandra_server_instance_num)) ]; then
            break
        fi
    done
done
#If has mod
if [ $already_schedled_instance_num -lt $cassandra_server_instance_num ]; then
    for(( node=0; node < $numa_node_num; node++ )); do
        start_cassandra_instance $already_schedled_instance_num $node
        already_schedled_instance_num=$(($already_schedled_instance_num + 1))
        if [ $(($already_schedled_instance_num)) -eq  $(($cassandra_server_instance_num)) ]; then
            break
        fi
    done
fi
wait

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -e

#set cassandra parameter in cassandra.yaml, no related with instance num
set_cassandra_param() {  
    cassandra_internode_timeout=false
    cassandra_cross_node_timeout=false
    for yaml in \
        native_transport_port \
        listen_address \
        rpc_address \
        broadcast_address \
        broadcast_rpc_address \
        num_tokens \
        concurrent_reads \
        concurrent_writes \
        endpoint_snitch \
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

    #Always set node 1 as seed
    #cassandra_seeds="${hostname_prefix}1.${service_name}"
    #Sometimes the dns server is not ready to resolve the new pod/service hostname, so wait
    for ((;;)); do
        cassandra_seeds=`getent hosts cassandra-node-1.cassandra-server-service | awk -F ' ' '{print $1}'`
        if [ -z "$cassandra_seeds" ]; then
            echo "Waitting to get cassandra seeds ip address."
            sleep 5
        else
            echo "Get cassandra_seeds ip address :$cassandra_seeds."
            break
        fi
    done
    sed_in_place "$CASSANDRA_CONF/cassandra.yaml" \
            -r 's/(- seeds:).*/\1 "'"$cassandra_seeds"'"/'
}

numa_node_num=1
get_numa_node_num() {    
    numa_node_num=`numactl --hardware | grep cpus | wc -l`      
}

#Set JVM parameters
set_JVM_param() {
    
    free_memory=`cat /proc/meminfo | egrep '^MemFree' | awk '{printf "%d\n", $2/1024/1024}'`

    if ${cluster_on_single_node}; then
        if  ${cassandra_numactl_enable:-true}; then 
            get_numa_node_num
            instance_per_numa=$(($NODE_NUM > $numa_node_num ? $NODE_NUM / $numa_node_num : 1)) 
        else
            numa_node_num=1
            instance_per_numa=$instance_num
        fi
        assignable_size=$((8 * $free_memory / 10 / $numa_node_num / $instance_per_numa))
    else
        assignable_size=$((9 * $free_memory / 10 ))
    fi
  
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
   
    #cdc_raw_directory
    cdc_line=`sed -n '/'"cdc_raw_directory:"'/=' $conf_path/cassandra.yaml`
    cdc_raw_directory="cdc_raw_directory: /$base_path/current_data/cdc_raw_directory"
    sed -i "${cdc_line}c $cdc_raw_directory" $conf_path/cassandra.yaml    

    #hints_directory
    hints_line=`sed -n '/'"hints_directory:"'/=' $conf_path/cassandra.yaml`
    hints_directory="hints_directory: /$base_path/current_data/hints"
    sed -i "${hints_line}c $hints_directory" $conf_path/cassandra.yaml
 
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

wait_seed_node_started() {
    port=$cassandra_native_transport_port
    seed_node="${hostname_prefix}1"
    hostname=`hostname`

    #seed node always cassandra-node-1. if seed node, return for starting up
    if [ "$hostname" == "$seed_node" ] ; then
        return 0
    fi   

    #cassandra node hostname like: cassandra-node-2
    pre_node_num=`echo $hostname | awk -F '-' '{print $3}'`    
    wait_node="${hostname_prefix}$(($pre_node_num-1)).${service_name}"
    #Here cassandra node needs to start up one by one to get token sequentially,
    #otherwise, token will be collision on some node
    for ((;;)); do
        state=`nmap -p $port $wait_node | grep "$port" | grep open || [[ $? == 1 ]]`
        if [ -z "$state" ]; then
            echo "Connection to $wait_node on port $native_transport_port has failed"
            sleep 2
        else
            echo "Connection to $wait_node on port $native_transport_port was successful"
            break
        fi
    done
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

    #if cluster, wait the first node started
    if [ "$deploy_mode" == "cluster" ]; then
        wait_seed_node_started
    fi

    export CASSANDRA_HOME="/$user_name" CASSANDRA_CONF="/${user_name}/conf"
    
    #If cluster_on_single_node=true, bound cassandra process to numa node one by one 
    #according to cassandra_numactl_enable status
    if ${cluster_on_single_node}; then
        get_numa_node_num
        #node_index start from 0
        node=$(( $node_index % $numa_node_num ))
    fi
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

kernel_param_set() {
    if ${KERNEL_TUNE} ; then
        . /usr/local/bin/kernel_tune.sh "server"
    fi
}

setup_ramdisk() {
    free_memory_size=`cat /proc/meminfo | egrep '^MemFree' | awk '{printf "%d\n", $2/1024/1024}'`
    #heap of Cassandra server process occupy half, so left half to ues
    avialiable_memory_size=$(($free_memory_size / 2))
    num=1
    if ${cluster_on_single_node}; then
        num=${NODE_NUM}
    fi

    available_size=$((9 * $avialiable_memory_size / $num / 10)) #Maximum use 90%
    path="/cassandra0/current_data"
    mkdir -p $path
    mount -t tmpfs -o size=${available_size}g ram_disk0 $path
}

#free cached memroy
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches

#Tune kernel
kernel_param_set

#Tune host network
host_network_set
#config ramdisk
if ${RAM_DISK_EANBLE}; then
    setup_ramdisk
fi
#set parameters which no ralated with instance num
set_cassandra_param
set_JVM_param
start_cassandra_instance 0 0
#start DB data clean process, two parameters
cassandra_install_dir="/"
cassandra_server_instance_num=1 #for cluster the value of cassandra_server_instance_num is always 1
nohup python3 /usr/local/bin/clean_data_server.py ${CLEAN_PORT} ${cassandra_server_instance_num} ${cassandra_install_dir} > clean_data_server.log &
wait

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -e

#set cassandra parameter in cassandra.yaml, no related with instance num
set_cassandra_param() {
    sed_in_place "$CASSANDRA_CONF/cassandra.yaml" \
        -r 's/(- seeds:).*/\1 "'"$cassandra_seeds"'"/'

    for yaml in \
        native_transport_port \
        rpc_address \
        broadcast_address \
        broadcast_rpc_address \
        num_tokens \
        concurrent_reads \
        concurrent_writes \
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
    data_path="    - /$base_path/current_data/data/"
    data_conf_line=`sed -n '/'"data_file_directories:"'/=' $conf_path/cassandra.yaml`
    data_path_line=$(($data_conf_line + 1))
    sed -i "${data_conf_line}c data_file_directories:" $conf_path/cassandra.yaml
    sed -i "${data_path_line}c  $data_path" $conf_path/cassandra.yaml

    #commit log path, default : decommitlog_directory: /var/lib/cassandra/commitlog
    commit_log_path_conf="commitlog_directory: /$base_path/current_data/commitlog"
    conf_line=`sed -n '/'"commitlog_directory:"'/=' $conf_path/cassandra.yaml`
    sed -i "${conf_line}c $commit_log_path_conf" $conf_path/cassandra.yaml

    #saved_caches_directory
    cache_line=`sed -n '/'"saved_caches_directory:"'/=' $conf_path/cassandra.yaml`
    caches_directory="saved_caches_directory: /$base_path/current_data/saved_caches"
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

#initialize pinned_vcores_list and pinned_numa_list
for ((i = 0; i < ${cassandra_server_instance_num}; i++)); do
  pinned_vcores_list[i]=""
  pinned_numa_list[i]=""
done
pinned_list_inx=0

get_vcores_list() {
    instance_num=${cassandra_server_instance_num}   	
	get_numa_node_num	
    div=$(( (instance_num + numa_node_num - 1) / numa_node_num)) #ceil
	
    # NUMA node0 CPU(s):     0-31,128-159
    # NUMA node1 CPU(s):     32-63,160-191
    # NUMA node2 CPU(s):     64-95,192-223
    # NUMA node3 CPU(s):     96-127,224-255
     numa_vcores_array=(`lscpu | grep 'NUMA node[0-9]' | awk -F ' ' '{print $4}'`)
     length=${#numa_vcores_array[@]}

    for ((numa_inx = 0; numa_inx < length; numa_inx++));do
        #split "0-31,128-159"
        IFS=',' element=(${numa_vcores_array[numa_inx]})
		for ((d = 0; d < div; d++));do
		    for ((e = 0; e < ${#element[@]}; e++));do
                #e.g. 0-31,get min: 0  max: 31
                min=`echo ${element[e]} | awk -F '-' '{print $1}'`
                max=`echo ${element[e]} | awk -F '-' '{print $2}'`
                num=$(( max - min + 1 ))
                interval=$(( (num+div-1)/div )) #ceil
                begin=$(( d * interval + min ))
                end=$(( begin + interval -1 )) #due to start from 0, so sub 1
				split_str=","
				if [ -z "${pinned_vcores_list[pinned_list_inx]}" ]; then
                    split_str=''
				fi
                pinned_vcores_list[pinned_list_inx]="${pinned_vcores_list[pinned_list_inx]}${split_str}${begin}-${end}"
				pinned_numa_list[pinned_list_inx]=${numa_inx}
            done
            pinned_list_inx=$(( pinned_list_inx + 1 ))
        done
    done
}

start_cassandra_instance() {
    index=$1
    get_numa_node_num
    node=$(( index % numa_node_num))
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
    #if set numactl_vcores_enable, pinned each instance to half physical vcores and half virtual vcores.
    #This pinned method can improve the throughput    
    vcores=${pinned_vcores_list[$index]}
    numa_node=${pinned_numa_list[$index]}
    if  ${cassandra_numactl_vcores_enable:-true}; then
        export NUMACTL_ARGS="-m $numa_node -C ${vcores}"        
    fi
    echo "DEBUG:Instance $index: NUMACTL_ARGS=$NUMACTL_ARGS"

    #start cassandra, use 'su' no 'su -' to inherite root env
    su $user_name<<EOF     
    nohup ${CASSANDRA_HOME}/bin/cassandra -f > ${CASSANDRA_HOME}/output-start-$node-$index.log &  
EOF
}

kernel_param_set() {
    if ${KERNEL_TUNE} ; then
        . /usr/local/bin/kernel_tune.sh "server"
    fi
}

host_network_set() {
    if ${HOST_NETWORK} && ${RPS_TUNE} ; then
        . /usr/local/bin/network_tune.sh
    fi
}

setup_ramdisk() {
    free_memory_size=`cat /proc/meminfo | egrep '^MemFree' | awk '{printf "%d\n", $2/1024/1024}'`
    #heap of Cassandra server process occupy half, so left half to ues
    avialiable_memory_size=$(($free_memory_size / 2))
    instance_num=${cassandra_server_instance_num}
    each_instance_size=$((9 * $avialiable_memory_size / $instance_num / 10)) #Maximum use 90%
    for(( index=0; index < $instance_num; index++ )); do
        path="/cassandra$index/current_data"
        mkdir -p $path
        mount -t tmpfs -o size=${each_instance_size}g  ram_disk$index $path
    done
}

#Tune kernel parameters
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
#get instance number on each numa node
get_numa_node_num
#for numactl_vcores_enable=true
get_vcores_list
#set instance parameters and start cassandra instance on each numa node
for(( inx=0; inx < $cassandra_server_instance_num; inx++ )); do
    start_cassandra_instance ${inx} 
done

#start DB data clean process, two parameters
cassandra_install_dir="/"
nohup python3 /usr/local/bin/clean_data_server.py ${CLEAN_PORT} ${cassandra_server_instance_num} ${cassandra_install_dir} > clean_data_server.log &

wait
#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

echo "preparing >>>"
source prepare_mongodb.sh

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

let PORT=$server_index
mongo_config_file='mongod.conf'
db_path="/var/lib/mongo/mongodb-server-$PORT"
log_path="/var/lib/mongo/mongo-$PORT.log"

# set mongodb db path and log oath
echo "Creating db folder $db_path"
rm -rf $db_path    # Ensure no db files exist from previous runs
mkdir -p $db_path  # Create DB subfolder

echo "Creating log file $log_path"
rm -rf $log_path
eval "touch $log_path"

# update mongodb configuration
sed -i -r -e "s#(.*path: ).*#\1$log_path#g" $mongo_config_file
sed -i -r -e "s#(.*dbPath: ).*#\1$db_path#g" $mongo_config_file
sed -i -r -e "s/(.*journalCompressor: ).*/\1$m_journalcompressor/g" $mongo_config_file
sed -i -r -e "s/(.*blockCompressor: ).*/\1$m_collectionconfig_blockcompressor/g" $mongo_config_file
sed -i -r -e "s/(.*fork: ).*/\1$m_process_management_fork/g" $mongo_config_file
[ "$m_cache_size_gb" == "" ] && {
    sed -i /cacheSizeGB:/d $mongo_config_file
} || {
    sed -i -r -e "s/(.*cacheSizeGB: ).*/\1$m_cache_size_gb/g" $mongo_config_file
}
# edit config and uncomment journaling and set it to selected setting if the versions supports it
# otherwise, remove completely from config file
mongodb_version=`./mongod --version | grep "db version" | awk '{print $3}'`
if [ ${mongodb_version} == "v4.4.1" ] || [ ${mongodb_version} == "v6.0.4" ]; then
    sed -i -r -e "s/.*(journal:).*/  \1/g" $mongo_config_file
    sed -i -r -e "s/.*(enabled:).*/    \1 $m_journal_enabled/g" $mongo_config_file
else
    sed -i -r -e "/journal:/d" $mongo_config_file
    sed -i -r -e "/enabled:/d" $mongo_config_file
fi
echo "--------------------------"
cat $mongo_config_file
echo "--------------------------"

# enbale tls
if [ $m_tls_flag -ne 0 ]
then
    # generate the ssl key
	openssl req -newkey rsa:2048 -new -x509 -days 3650 -nodes -out moncaone.crt -keyout moncaone.key -subj '/CN=mongodb-server-service-'${server_index} 
	sed wmoncaone-${server_index}.pem moncaone.crt moncaone.key >/dev/null
	cp  moncaone-${server_index}.pem /usr/src/mongodb/moncaone.pem
	redis-cli -h config-center -p $m_config_center_port -x HSET moncaone-${server_index} pem_binary <moncaone-${server_index}.pem
    # update the config file
	sed -i -e '/bindIp:/a\    certificateKeyFile: /usr/src/mongodb/moncaone.pem' $mongo_config_file
	sed -i -e '/bindIp:/a\    mode: requireTLS' $mongo_config_file
	sed -i -e '/bindIp:/a\  tls:' $mongo_config_file
fi

# set numa policy on mongod
NUMA_POLICY=""
if [[ -n $m_customer_numaopt_server ]]; then
    NUMA_POLICY=$m_customer_numaopt_server
else
    ## 0 - mongodb default option, numactl --interleave=all
    ## 1 - bind all mongodb instances to all numanode evenly
    ## 2 - bind all mongodb instances to a selected numanode, if cores was specified mongodb instances would be bounded with the selected cores.
    ## 3 - each mongodb instance will be bounded with specific number of cores
    ## 4 - each mongodb instance will be bounded with specific number of cores paied with their logical cores.
    ## 5 - no numactl.
    if [ ${m_numactl_option} == "0" ]
    then
        echo "m_numactl_option is 0, mongodb default bind, numactl --interleave=all"
        NUMA_POLICY="numactl --interleave=all"
    elif [ ${m_numactl_option} == "1" ]
    then
        echo "m_numactl_option is 1, bind all mongodb instances to all numanode evenly "
        let node_id=${server_index}%2
        echo "server ${server_index} is binded to numa node $node_id"
        NUMA_POLICY="numactl --cpunodebind=${node_id} --membind=${node_id}"
    elif [ ${m_numactl_option} == "2" ]
    then
        echo "m_numactl_option is 2, bind all mongodb instances to numanode $m_select_numa_node"
        node_id=${m_select_numa_node}
        echo "server ${server_index} is binded to numa node $node_id"
        if [[ -z "$m_cores" ]]; then
            NUMA_POLICY="numactl --cpunodebind=${node_id} --membind=${m_select_numa_node}"
        else
            echo "and bind all mongodb instances to cores: $m_cores"
            NUMA_POLICY="numactl --physcpubind=${m_cores} --membind=${m_select_numa_node}"
        fi
    elif [ ${m_numactl_option} == "3" ]
    then
        echo "m_numactl_option is 3, each mongodb instance will be bounded with ${m_core_nums_each_instance} cores"
        # check the connection to config center
        connection_check "config-center" $m_config_center_port
        let INSTANCE_INDEX=$(redis-cli -h config-center -p $m_config_center_port incr instance_index)-1
        tmpbind="$(($INSTANCE_INDEX*${m_core_nums_each_instance}))-$(($INSTANCE_INDEX*${m_core_nums_each_instance}+${m_core_nums_each_instance}-1))"
        echo "**instance($INSTANCE_INDEX) will be bounded on core:${tmpbind}**"
        NUMA_POLICY="numactl --physcpubind=$tmpbind --localalloc"
    elif [ ${m_numactl_option} == "4" ]
    then
        echo "m_numactl_option is 4, each mongodb instance will be bounded with ${m_core_nums_each_instance} cores with their logical cores when HT enabled"
        # check the connection to config center
        connection_check "config-center" $m_config_center_port
        let INSTANCE_INDEX=$(redis-cli -h config-center -p $m_config_center_port incr instance_index)-1
        start_cpuno=$(($INSTANCE_INDEX*${m_core_nums_each_instance}))
        cpuset=$(cat /sys/devices/system/cpu/cpu${start_cpuno}/topology/thread_siblings_list)
        if [[ "$cpuset" == *","* ]]; then
            echo "HT-ON MODE"
        else
            echo "HT-OFF MODE" 
        fi
        for((i=1;i<${m_core_nums_each_instance};i++));
        do
            cpuindex=$(($INSTANCE_INDEX*${m_core_nums_each_instance}+${i}))
            tmpcpuset=$(cat /sys/devices/system/cpu/cpu${cpuindex}/topology/thread_siblings_list)
            cpuset="${cpuset},${tmpcpuset}"
        done
        echo "**instance($INSTANCE_INDEX) will be bounded on core:${cpuset}**"
        NUMA_POLICY="numactl --physcpubind=$cpuset --localalloc"    
    elif [ ${m_numactl_option} == "5" ]
    then
        NUMA_POLICY=""
    fi
fi

# run mongod
${NUMA_POLICY} ./mongod --port ${PORT} --bind_ip_all -f $mongo_config_file

#!/bin/bash

echo "preparing >>>"
source prepare_mongodb.sh

let PORT=$server_index
mongo_config_file='mongod.conf'
db_path="/var/lib/mongodb/mongodb-server-$PORT"
log_path="/var/log/mongodb/mongo-$PORT.log"

echo "Creating db folder $db_path"
rm -rf $db_path    # Ensure no db files exist from previous runs
mkdir -p $db_path  # Create DB subfolder

echo "Creating log file $log_path"
mkdir -p /var/log/mongodb
rm -rf /var/log/mongodb/*
eval "touch $log_path"

# config mongodb
sed -i -r -e "s#(.*path: ).*#\1$log_path#g" $mongo_config_file
sed -i -r -e "s#(.*dbPath: ).*#\1$db_path#g" $mongo_config_file
sed -i -r -e "s/(.*enabled: ).*/\1$m_journal_enabled/g" $mongo_config_file
sed -i -r -e "s/(.*blockCompressor: ).*/\1$m_collectionconfig_blockcompressor/g" $mongo_config_file
[ "$m_cache_size_gb" == "" ] && {
    sed -i /cacheSizeGB:/d $mongo_config_file
} || {
    sed -i -r -e "s/(.*cacheSizeGB: ).*/\1$m_cache_size_gb/g" $mongo_config_file
}
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

NUMA_POLICY=""
if [[ -n $m_customer_numaopt_server ]]; then
    NUMA_POLICY=$m_customer_numaopt_server
else
    ## 0 - mongodb default option, numactl --interleave=all
    ## 1 - bind all mongodb instances to all numanode evenly
    ## 2 - bind all mongodb instances to a selected numanode, 
    ##     if cores was specified mongodb instances would be bounded with the selected cores.
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
    fi
fi
${NUMA_POLICY} ./mongod --port ${PORT} --bind_ip_all -f $mongo_config_file
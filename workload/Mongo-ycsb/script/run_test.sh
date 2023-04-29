#!/bin/bash

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

cd /usr/src/ycsb/

# check the connection to mongodb
connection_check $HOST $PORT

echo "CONFIG_CENTER_PORT is :[$m_config_center_port]"
echo "CLIENT_SERVER_PAIR is :[$m_client_server_pair]"
echo "THREADS is :[$threads]"
echo "OPERATION_COUNT is :[$operation_count]"
echo "RECORD_COUNT is :[$record_count]"
echo "INSERT_START is :[$insert_start]"
echo "INSERT_COUNT is :[$insert_count]"
echo "testcase is :[$test_case]"

echo "FIELD_COUNT is :[$m_field_count]"
echo "FIELD_LENGTH is :[$m_field_length]"
echo "MIN_FIELD_LENGTH is :[$m_min_field_length]"
echo "READ_ALL_FIELDS is :[$m_read_all_fields]"
echo "WRITE_ALL_FIELDS is :[$m_write_all_fields]"
echo "READ_PROPORTION is :[$m_read_proportion]"
echo "UPDATE_PROPORTION is :[$m_update_proportion]"
echo "INSERT_PROPORTION is :[$m_insert_proportion]"
echo "SCAN_PROPORTION is :[$m_scan_proportion]"
echo "READ_MODIFY_WRITE_PROPORTION is :[$m_read_modify_write_proportion]"
echo "REQUEST_DISTRIBUTION is :[$m_request_distribution]"
echo "MIN_SCANLENGTH is :[$m_min_scanlength]"
echo "MAX_SCANLENGTH is :[$m_max_scanlength]"
echo "SCAN_LENGTH_DISTRIBUTION is :[$m_scan_length_distribution]"
echo "ZERO_PADDING is :[$m_zero_padding]"
echo "INSERT_ORDER is :[$m_insert_order]"
echo "FIELD_NAME_PREFIX is :[$m_field_name_prefix]"
echo "MAX_EXECUTION_TIME is :[$m_max_execution_time]"
echo "JVM_ARGS is :[$m_jvm_args]"
echo "TARGET is :[$m_target]"
echo "TLS_FLAG is :[$m_tls_flag]"

if [ $m_tls_flag -eq 0 ]
then
	ycsb_params=" -threads $threads -p operationcount=$operation_count -p recordcount=$record_count -p fieldcount=${m_field_count} -p fieldlength=${m_field_length} -p minfieldlength=${m_min_field_length} -p readallfields=${m_read_all_fields} -p writeallfields=${m_write_all_fields} -p readproportion=${m_read_proportion} -p updateproportion=${m_update_proportion} -p insertproportion=${m_insert_proportion} -p scanproportion=${m_scan_proportion} -p readmodifywrite_proportion=${m_read_modify_write_proportion} -p requestdistribution=${m_request_distribution} -p minscanlength=${m_min_scanlength} -p maxscanlength=${m_max_scanlength} -p scanlengthdistribution=${m_scan_length_distribution} -p zeropadding=${m_zero_padding} -p insertorder=${m_insert_order} -p fieldnameprefix=${m_field_name_prefix}  -p mongodb.url=mongodb://${HOST}:${PORT}/ycsb?maxPoolSize=1500 -p measurementtype=${m_ycsb_measurement_type}"
else
    # read tls key from redis
	until redis-cli -h config-center -p $m_config_center_port --raw HGET moncaone-${PORT} pem_binary  > /jdk/jdk-version/lib/security/moncaone-${PORT}.pem; do
		echo "moncaone-${PORT}.pem is not in the redis"
	done
	# rm older version will generate error
	#rm /jdk/jdk-version/lib/security/cacerts -f 
	keytool -import -noprompt -trustcacerts -alias cacert -storepass changeit -keystore /jdk/jdk-version/lib/security/cacerts -file /jdk/jdk-version/lib/security/moncaone-${PORT}.pem
    # update the ycsb_params
	ycsb_params=" -threads $threads -p operationcount=$operation_count -p recordcount=$record_count -p fieldcount=${m_field_count} -p fieldlength=${m_field_length} -p minfieldlength=${m_min_field_length} -p readallfields=${m_read_all_fields} -p writeallfields=${m_write_all_fields} -p readproportion=${m_read_proportion} -p updateproportion=${m_update_proportion} -p insertproportion=${m_insert_proportion} -p scanproportion=${m_scan_proportion} -p readmodifywrite_proportion=${m_read_modify_write_proportion} -p requestdistribution=${m_request_distribution} -p minscanlength=${m_min_scanlength} -p maxscanlength=${m_max_scanlength} -p scanlengthdistribution=${m_scan_length_distribution} -p zeropadding=${m_zero_padding} -p insertorder=${m_insert_order} -p fieldnameprefix=${m_field_name_prefix}  -p mongodb.url=mongodb://${HOST}:${PORT}/ycsb?ssl=true&maxPoolSize=1500 -p measurementtype=${m_ycsb_measurement_type}"
fi

# numa policy for ycsb
## for multi-node scenario, it is recommended not to set numa policy;
## customize numa ploicy for ycsb bu setting CUSTOMER_NUMAOPT_CLIENT;
## for single node scenario, it is recommended bound ycsb to differnet socket with mongodb
NUMA_POLICY=""
if [[ -n $m_customer_numaopt_client ]]; then
    NUMA_POLICY=$m_customer_numaopt_client
elif [[ $m_run_single_node == "true" ]] || [ $m_client_count -eq 0 ] && [ $m_numactl_option -eq 2 ]; then
    if [[ -n "$m_ycsb_cores" ]]; then
        NUMA_POLICY="numactl --physcpubind=${m_ycsb_cores} --localalloc"
    else
        node_id=${m_select_numa_node}
        NUMA_POLICY="numactl --cpunodebind=!${node_id} --localalloc"
    fi
fi

echo "NUMA_POLICY: ${NUMA_POLICY}"

echo "[LOAD PHASE]"
${NUMA_POLICY} ./bin/ycsb load mongodb -s ${ycsb_params} -P workloads/$workload_file && {
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

echo "[RUN PHASE]"
${NUMA_POLICY} ./bin/ycsb run mongodb -s -target $m_target -jvm-args="$m_jvm_args" -P workloads/$workload_file -p insertstart=$insert_start -p insertcount=$insert_count -p maxexecutiontime=${m_max_execution_time} ${ycsb_params}

echo "benchmark-finish"

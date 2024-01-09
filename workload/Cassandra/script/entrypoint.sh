#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#sh ./config.sh
#yes | cp cassandra.yaml conf/

DEPLOY_MODE="${deploy_mode:=standalone}"
NODE_NUM="${node_num:=1}"
SERVICE_NAME="${service_name:=cassandra-server-service}"
FILL_DATA="${fill_data:=false}"
INSERT="${insert:=30}"
SIMPLE1="${simple:=70}"
DURATION="${duration:=10m}"
NODE="${node:=cassandra-server-service}"
THREADS="${threads:=16}"
CL="${cl:=ONE}"
RETRIES="${retries:=10}"
INSTANCE_NUM=${client_instance_num:=1}
STRESS_NUM=${stress_number:=1}
SERVER_PORT=${server_port:=9042}
POP_MIN=${pop_min:=1}
POP_MAX=${pop_max:=100}
POP_PERFORMANCE_DIV=${pop_performance_div:=1}
#below for DB table in cqlstress-insanity-example.yaml
CHUNK_LENGTH="${data_chunk_size:=64}" #KB
COMPACTION="${data_compaction:=SizeTieredCompactionStrategy}"
COMPRESSION="${data_compression:=LZ4Compressor}"
REPLICATE_NUM="${replicate_num:=3}"
CLEAN_PORT="${clean_port:=30000}"
KERNEL_TUNE="${kernel_tune:=false}"

#set cqlstress-insanity-example.yaml
file_cqlstress_insanity="./tools/cqlstress-insanity-example.yaml"
compact_line=`sed -n '/'")\s*WITH\s*compaction\s*=\s*{"'/=' $file_cqlstress_insanity`
compaction_conf="\\  \\) WITH compaction = { 'class':'$COMPACTION' }"
compression_conf="\\    \\AND compression = { 'class' : '$COMPRESSION', 'chunk_length_in_kb' : $CHUNK_LENGTH }"
sed -i "${compact_line}c $compaction_conf" $file_cqlstress_insanity
sed -i "${compact_line}a $compression_conf" $file_cqlstress_insanity

kernel_param_set() {
    if ${KERNEL_TUNE} ; then
        ./kernel_tune.sh "client"
    fi
}

wait_server_nodes_started() {
    port=$cassandra_native_transport_port
    server_node=""

    for ((;;)); do
        count=0
        for ((i = 1; i <= $NODE_NUM; i++)); do
            server_node="${hostname_prefix}$i.${SERVICE_NAME}"
            state=`nmap -p $SERVER_PORT $server_node | grep "$SERVER_PORT" | grep open || [[ $? == 1 ]]`
            if [ -z "$state" ]; then
                echo "Port $SERVER_PORT on $server_node has not started."
                sleep 5
            else
                echo "Port $SERVER_PORT on $server_node started successfully."
                ((count++))
            fi
        done
        if [ $count -eq $NODE_NUM ]; then
            break
        fi
    done
}

#call kernel param set function
kernel_param_set

POP_MAX_TEST=$(($POP_MAX / $POP_PERFORMANCE_DIV ))
if [ "$DEPLOY_MODE" == "cluster" ]; then
    #set the essential parameters for cluster
    if [ $REPLICATE_NUM -gt $NODE_NUM ]; then
        REPLICATE_NUM=$NODE_NUM
    fi
    replication_line=`sed -n '/'"CREATE KEYSPACE stresscql WITH replication\s*=\s*{"'/=' $file_cqlstress_insanity`
    replication_conf="\\  \\CREATE KEYSPACE stresscql WITH replication = {'class': 'SimpleStrategy', 'replication_factor': $REPLICATE_NUM};"    
    sed -i "${replication_line}c $replication_conf" $file_cqlstress_insanity
    INSTANCE_NUM=1
    CL=QUORUM
    echo "POP_MAX:$POP_MAX, POP_MAX_TEST:$POP_MAX_TEST, div:$POP_PERFORMANCE_DIV"
    echo "Waiting for server nodes started"
    wait_server_nodes_started
fi

echo "DEBUG_MODE is :[$m_debug_mode]"
# in debug mode, generate the pre-hook begin flage and waiting for pre-hook end flag
if [ $m_debug_mode -eq 1 ]
then
        rm /usr/src/hook/*_hook_* -f
        touch /usr/src/hook/pre_hook_begin_client
        i=30
        pre_hook_flag=1
        while [ ! -f /usr/src/hook/pre_hook_end ]; do
                if [ $i == 0 ]
                then
                        pre_hook_flag=0
                        break
                fi
                let i--
                sleep 10
        done
        echo "************PRE_HOOK_FLAG is :[$pre_hook_flag]"
fi

#Prepare work to create database and fill data
echo "Begin to prepare data"
if ${FILL_DATA}; then
    if [ "$DEPLOY_MODE" == "cluster" ]; then
        fill_round=1
        port=$SERVER_PORT
        NODE="${hostname_prefix}1.${SERVICE_NAME}"
    else
        fill_round=$INSTANCE_NUM
    fi 
    for ((i=0;i<fill_round;i++))
    do
    {
        port=$(($SERVER_PORT+$i))
        ./tools/bin/cassandra-stress user profile=./tools/cqlstress-insanity-example.yaml \
        ops\(insert=1\) no-warmup cl=$CL n=$POP_MAX -mode native cql3 \
        -pop seq=1..$POP_MAX -node $NODE -port native=$port \
        -rate threads=$THREADS  > fill_data_output_${i}_${port}.log
    } &
        sleep 1
    done
wait
fi

#Need to wait data compaction finished before performance testing
python3 clean_data_client.py "compact_wait" ${NODE} ${CLEAN_PORT} > clean_data_client_output.log

echo "End preparing data"

#Do performance testing
echo "Begin performance testing"
#In cluster node INSTANCE_NUM always 1
for ((i=0;i<INSTANCE_NUM;i++))
do
    if [ "$DEPLOY_MODE" == "cluster" ]; then
        port=$SERVER_PORT       
    else
        port=$(($SERVER_PORT+$i))
    fi

    for ((n=0;n<STRESS_NUM;n++))
    do
    {   
        if [ "$DEPLOY_MODE" == "cluster" ]; then
            NODE="${hostname_prefix}$(($n+1)).${SERVICE_NAME}"
        fi 
        ./tools/bin/cassandra-stress user profile=./tools/cqlstress-insanity-example.yaml \
        ops\(insert=$INSERT,simple1=$SIMPLE1\) no-warmup cl=$CL duration=$DURATION \
        -mode native cql3 -pop dist=uniform\($POP_MIN..$POP_MAX_TEST\) -node $NODE -port native=$port \
        -rate threads=$THREADS > benchmark_output_${i}_${port}_${n}.log
    } &
        sleep 1
    done
done
wait
echo "End performance testing"

#Send message to server to delete DB data
if [ "$DEPLOY_MODE" == "cluster" ]; then
    #need to clean data for each node
    for ((i = 1; i <= $NODE_NUM; i++)); do
        server_node="${hostname_prefix}$i.${SERVICE_NAME}"
        python3 clean_data_client.py "clean" ${server_node} ${CLEAN_PORT} >> clean_data_client_output.log
    done
else
    #standalone mode
    python3 clean_data_client.py "clean" ${NODE} ${CLEAN_PORT} >> clean_data_client_output.log
fi

# in debug mode, generate the post-hook begin flage and waiting for post-hook end flag
if [ $m_debug_mode -eq 1 ]
then
	while [ `ps -ef | grep "cassandra-stress" | grep -v grep | head -1 | awk '{print $2}'` ]; do
		#pids=`ps -ef | grep "cassandra-stress" | grep -v grep | awk '{print $2}'`
		sleep 10
	done

	rm /usr/src/hook/*_hook_* -f
        touch /usr/src/hook/post_hook_begin_client
        i=30
        post_hook_flag=1
        while [ ! -f /usr/src/hook/post_hook_end ]; do
                if [ $i == 0 ]
                then
                        post_hook_flag=0
                        break
                fi
                let i--
                sleep 20
        done
        echo "************POST_HOOK_FLAG is :[$post_hook_flag]"
fi

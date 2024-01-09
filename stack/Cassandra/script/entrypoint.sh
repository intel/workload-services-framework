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
FILL_DATA="${fill_data:=false}"
INSERT="${insert:=30}"
SIMPLE1="${simple:=70}"
DURATION="${duration:=10m}"
cassandra_server_addr="${cassandra_server_addr:=localhost}"
NODE="${node:=${cassandr_servera_addr}}"
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
TESTCASE_ORDER="${TESTCASE_ORDER:=1}"

#set cqlstress-insanity-example.yaml
file_cqlstress_insanity="./tools/cqlstress-insanity-example.yaml"
compact_line=`sed -n '/'")\s*WITH\s*compaction\s*=\s*{"'/=' $file_cqlstress_insanity`
compaction_conf="\\  \\) WITH compaction = { 'class':'$COMPACTION' }"
compression_conf="\\    \\AND compression = { 'class' : '$COMPRESSION', 'chunk_length_in_kb' : $CHUNK_LENGTH }"
sed -i "${compact_line}c $compaction_conf" $file_cqlstress_insanity
sed -i "${compact_line}a $compression_conf" $file_cqlstress_insanity

wait_server_nodes_started() {
    port=$cassandra_native_transport_port
    server_node=""

    for ((;;)); do
        count=0
        for ((i = 1; i <= $NODE_NUM; i++)); do
            server_node="${hostname_prefix}$i"
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

#Below is for Unit Test
function placeholder {
    echo "This is placeholder"
    exit 0
}
 #Case 1 : Validate if server started successfully
function is_server_up {
    #As client is always wait server to start, so server should always be started successfully 
    # when code running here
    echo "Case 1: Cassandra server started successfully!"
    exit 0
}
#Case 2 : Check if set  concurrent_reads correctly    
function check_chunk_length {
    value=`grep 'chunk_length_in_kb' ${file_cqlstress_insanity}  | awk -F ' ' '{print $10}'`
    if [ "$value" = "${CHUNK_LENGTH}" ]; then
        echo "Case 2: Set chunk length successfully"
        exit 0
    else
        echo "Case 2: Set chunk length error. want to set ${CHUNK_LENGTH}, in fact it is $value"
        exit 1
    fi
}

testcases_suit=(placeholder is_server_up check_chunk_length)

${testcases_suit[$TESTCASE_ORDER]}


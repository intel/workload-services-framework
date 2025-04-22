#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This script is used to run producer tasks, consumer tasks and create Kafka topic

sleep 20

# Parameters
export K_KAFKA_DIR=$KAFKA_HOME
export K_KAFKA_CONSUMER_GROUP_ID="PKB_CONSUMER_GROUP"

# Enable kafka encryption and authentication with SSL
if [[ ${K_ENCRYPTION} == true ]]; then
    echo "security.protocol=SSL" >> ${KAFKA_HOME}/config/client-ssl.properties
    echo "ssl.truststore.location=/opt/ca/kafka.client.truststore.jks" >> ${KAFKA_HOME}/config/client-ssl.properties
    echo "ssl.truststore.password=${PASSWD}" >> ${KAFKA_HOME}/config/client-ssl.properties
    echo "ssl.endpoint.identification.algorithm=" >> ${KAFKA_HOME}/config/client-ssl.properties
    chmod +x ${KAFKA_HOME}/config/client-ssl.properties
fi

# Consumer and producer wait for topic creating done
if [[ ${K_IDENTIFIER} == producer ]] || [[ ${K_IDENTIFIER} == consumer ]]; then
    sleep 30
    if [[ ${K_ENCRYPTION} == true ]]; then
        until sh ${K_KAFKA_DIR}/bin/kafka-topics.sh --list --bootstrap-server ${K_KAFKA_SERVER} --command-config ${K_KAFKA_DIR}/config/client-ssl.properties | grep ${K_KAFKA_BENCHMARK_TOPIC}${K_TOPIC_NUM}
        do
            echo waiting for topic
            sleep 10
        done
    else
        until sh ${K_KAFKA_DIR}/bin/kafka-topics.sh --list --bootstrap-server ${K_KAFKA_SERVER} | grep ${K_KAFKA_BENCHMARK_TOPIC}${K_TOPIC_NUM}
        do
            echo waiting for topic
            sleep 10
        done
    fi
fi

source ${BASE_DIR}/common.sh

# Calculate default PARTITIONS/PRODUCERS/CONSUMERS load according to CPU cores and free memory size(GB)
load_factor=1
if [[ ${K_SERVER_CORE_NEEDED_FACTOR:-1} != 1 ]]; then # Single node scenario
    load_factor=$(echo "${K_SERVER_CORE_NEEDED_FACTOR}" | awk '{ printf("%.2f\n", (1 - $1) / 2) }')
fi
cores=`cat /proc/cpuinfo | grep "processor" | wc -l`
free_memory=`cat /proc/meminfo | egrep '^MemFree' | awk '{printf "%.0f\n", $2/1024}'`
if [[ $free_memory == 0 ]]; then
    echo "No free memory left"
    exit 1
fi
free_memory=`expr $free_memory / 1024 + 1`
default_load=$(echo "$((cores < free_memory ? cores : free_memory)) $load_factor" | awk '{ printf("%.0f\n", $1 * $2) }')
echo "CPU Cores: $cores"
echo "Free Memory: $free_memory"
echo "Load Factor: $load_factor"
echo "Default Load: $default_load"
if [[ $K_PRODUCERS != 0 ]] && [[ $K_PRODUCERS -ge $K_PRODUCER_NODE_NUM ]]; then K_PRODUCERS=$(expr $K_PRODUCERS / $K_PRODUCER_NODE_NUM); fi
if [[ $K_PARTITIONS == 0 ]]; then K_PARTITIONS=$default_load; fi
if [[ $K_PRODUCERS == 0 ]]; then K_PRODUCERS=$default_load; fi
if [[ $K_CONSUMERS == 0 ]]; then K_CONSUMERS=$default_load; fi


wait_broker
if [[ ${K_IDENTIFIER} == topic ]]; then
    echo "Creating topic..."
    if [[ ${K_ENCRYPTION} == true ]]; then
        for ((i=1; i<=K_TOPIC_NUM; i++)); do
            until sh ${K_KAFKA_DIR}/bin/kafka-topics.sh --create --bootstrap-server ${K_KAFKA_SERVER} --replication-factor ${K_REPLICATION_FACTOR} --partitions ${K_PARTITIONS} --topic ${K_KAFKA_BENCHMARK_TOPIC}$i --command-config ${KAFKA_HOME}/config/client-ssl.properties
            do
                echo topic creating
                sleep 5
            done
        done
    else
        for ((i=1; i<=K_TOPIC_NUM; i++)); do
            until sh ${K_KAFKA_DIR}/bin/kafka-topics.sh --create --bootstrap-server ${K_KAFKA_SERVER} --replication-factor ${K_REPLICATION_FACTOR} --partitions ${K_PARTITIONS} --topic ${K_KAFKA_BENCHMARK_TOPIC}$i
            do
              echo topic creating
              sleep 5
            done
        done
    fi
elif [[ ${K_IDENTIFIER} == producer ]]; then
    if [ "x$K_KAFKA_HEAP_OPTS" = "x" ]; then
        export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
    else
        export KAFKA_HEAP_OPTS=${K_KAFKA_HEAP_OPTS//_/ }
    fi
    if [[ ${K_SERVER_PROTECTION} == true ]]; then
        limit_num_records
        limit_producers
    fi
    echo "Starting producer..."
    echo "begin region of interest"
    $(get_numa_cmd 'PRODUCER') python3 start_test.py
    echo "end region of interest"
elif [[ ${K_IDENTIFIER} == consumer ]]; then
    echo "Starting consumer..."
    echo "begin region of interest"
    export K_TOPIC_NUM=1
    $(get_numa_cmd 'CONSUMER') python3 start_test.py
    echo "end region of interest"
else
    echo "Unknown identifier!"
fi

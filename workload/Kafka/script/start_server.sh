#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This script is used to start Kafka and Zookeeper server

if [[ ${K_ENABLE_MUL_DISK} == true ]]; then
    kafka_disk=""
    for ((i=0; i<${K_MOUNT_DISK_COUNT}; i++)); do
        if [[ -n $kafka_disk ]]; then
            kafka_disk="$kafka_disk,/data/kafka$i"
	else
            kafka_disk="/data/kafka$i"
	fi
    done
    echo "mount disk: $kafka_disk"
    sed -i "s|^log.dirs=.*$|log.dirs=${kafka_disk}|" ${KAFKA_HOME}/config/server.properties
fi

source ${BASE_DIR}/common.sh

NUMACTL_CMD=$(get_numa_cmd 'SERVER')

BROKER_ID=$(echo ${POD_NAME}|awk -F - '{print $4}')

if [[ ${K_ENCRYPTION} == true ]]; then
    protocol=SSL
    echo "ssl.keystore.location=${BASE_DIR}/ca/kafka.server.keystore.jks" >> ${KAFKA_SERVER_CONFIG}
    echo "ssl.keystore.password=${PASSWD}" >>  ${KAFKA_SERVER_CONFIG}
    echo "ssl.key.password=${PASSWD}" >> ${KAFKA_SERVER_CONFIG}
    echo "ssl.truststore.location=${BASE_DIR}/ca/kafka.server.truststore.jks" >> ${KAFKA_SERVER_CONFIG}
    echo "ssl.truststore.password=${PASSWD}" >> ${KAFKA_SERVER_CONFIG}
    echo "ssl.endpoint.identification.algorithm=" >> ${KAFKA_SERVER_CONFIG}
    echo "ssl.client.auth=none" >> ${KAFKA_SERVER_CONFIG}
    echo "ssl.secure.random.implementation=SHA1PRNG" >> ${KAFKA_SERVER_CONFIG}
    echo "security.inter.broker.protocol=SSL" >> ${KAFKA_SERVER_CONFIG}
else
    protocol=PLAINTEXT
fi
cores=`cat /proc/cpuinfo | grep "processor" | wc -l`
if [[ ${K_NUM_NETWORK_THREADS} == 0 ]]; then
    network_threads=$(echo "${cores}" | awk '{ printf("%.0f\n", $1 / 2) }')
    echo "num.network.threads is set to half of the core number"
else
    network_threads=${K_NUM_NETWORK_THREADS}
fi
echo "num.network.threads is set to ${network_threads}"
io_threads=${cores}

zk_server_ip=`parser_ip_by_domain  zookeeper-kafka-server-0.zookeeper-kafka-server-service`

echo "listeners=${protocol}://:9092" >> ${KAFKA_SERVER_CONFIG}
echo "advertised.listeners=${protocol}://${POD_NAME}.zookeeper-kafka-server-service:9092" >> ${KAFKA_SERVER_CONFIG}
sed -i "s|^zookeeper.connect=.*$|zookeeper.connect=${zk_server_ip}:2181|" ${KAFKA_SERVER_CONFIG}
sed -i "s|^broker.id=.*$|broker.id=${BROKER_ID}|" ${KAFKA_SERVER_CONFIG}
sed -i "s|^num.network.threads=.*$|num.network.threads=${network_threads}|" ${KAFKA_SERVER_CONFIG}
sed -i "s|^num.io.threads=.*$|num.io.threads=${io_threads}|" ${KAFKA_SERVER_CONFIG}
echo "num.replica.fetchers=${K_NUM_REPLICA_FETCHERS}" >> ${KAFKA_SERVER_CONFIG}
echo "replica.fetch.max.bytes=${K_REPLICA_FETCH_MAX_BYTES}" >> ${KAFKA_SERVER_CONFIG}
echo "replica.socket.receive.buffer.bytes=${K_REPLICA_SOCKET_RECEIVE_BUFFER_BYTES}" >> ${KAFKA_SERVER_CONFIG}

sysctl -w vm.dirty_background_ratio=60
sysctl -w vm.dirty_ratio=90
sysctl -w vm.dirty_writeback_centisecs=2000
sysctl -w vm.dirty_expire_centisecs=12000

if [ "x$K_KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
else
    export KAFKA_HEAP_OPTS=${K_KAFKA_HEAP_OPTS//_/ }
fi

if [[ ${BROKER_ID} == "0" ]]; then
    $NUMACTL_CMD ${KAFKA_HOME}/bin/zookeeper-server-start.sh -daemon ${KAFKA_HOME}/config/zookeeper.properties >> ${ZOOKEEPER_HOME}/zookeeper_start.out 2>&1 
    wait_zk
    update_server_free_space
    update_server_network_bandwith
else
    wait_zk
    until nc -z -w5 zookeeper-kafka-server-0.zookeeper-kafka-server-service 9092 2>/dev/null
    do
        echo "broker ${BROKER_ID} is waiting broker 0 start first"
        sleep 5
    done
fi
$NUMACTL_CMD ${KAFKA_HOME}/bin/kafka-server-start.sh -daemon ${KAFKA_HOME}/config/server.properties >> ${KAFKA_HOME}/kafka_start.out 2>&1
echo "broker ${BROKER_ID} started"

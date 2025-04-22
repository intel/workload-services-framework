changecom(`@')
# zookeeper-kafka-server-patsubst(WORKLOAD,`.*_',`')
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG `RELEASE'
ARG `IMAGESUFFIX'
FROM patsubst(WORKLOAD,`_',`-')-base`${IMAGESUFFIX}${RELEASE}'

# Prepare Kafka
ARG KAFKA_VER=3.8.0
ARG SCALA_VER=2.12
ARG KAFKA_FILE_NAME=kafka_${SCALA_VER}-${KAFKA_VER}.tgz
ARG KAFKA_PKG=https://archive.apache.org/dist/kafka/${KAFKA_VER}/${KAFKA_FILE_NAME}
ARG SCALA_PKG=https://archive.apache.org/dist/kafka/${KAFKA_VER}/${KAFKA_FILE_NAME}
ARG KAFKA_DIR=${BASE_DIR}/kafka_${SCALA_VER}-${KAFKA_VER}
ARG KAFKA_LOGS=${BASE_DIR}/kafka_logs
RUN mkdir -p ${KAFKA_LOGS} \
    && sed -i "s|^log.dirs=.*$|log.dirs=${KAFKA_LOGS}|" ${KAFKA_DIR}/config/server.properties \
    && echo "delete.topic.enable = true" >> ${KAFKA_DIR}/config/server.properties 
    
# Copy scripts
COPY script/common.sh ${BASE_DIR}
COPY script/start_server.sh ${BASE_DIR}

# Start services
CMD ./start_server.sh && sleep infinity

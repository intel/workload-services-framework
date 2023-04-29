changecom(`@')
# zookeeper-kafka-server-patsubst(WORKLOAD,`.*_',`')
changecom(`#')

ARG RELEASE
ARG IMAGESUFFIX
FROM patsubst(WORKLOAD,`_',`-')-base${IMAGESUFFIX}RELEASE

# Prepare Kafka
ARG KAFKA_VER=3.2.0
ARG KAFKA_DIR=${BASE_DIR}/kafka_2.12-${KAFKA_VER}
ARG KAFKA_LOGS=${BASE_DIR}/kafka_logs
RUN mkdir -p ${KAFKA_LOGS} \
    && sed -i "s|^log.dirs=.*$|log.dirs=${KAFKA_LOGS}|" ${KAFKA_DIR}/config/server.properties \
    && echo "delete.topic.enable = true" >> ${KAFKA_DIR}/config/server.properties 
    
# Copy scripts
COPY script/common.sh ${BASE_DIR}
COPY script/start_server.sh ${BASE_DIR}

# Start services
CMD ./start_server.sh && sleep infinity

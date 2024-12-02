changecom(`@')
# STACK-base
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ARG `RELEASE'
ARG `IMAGESUFFIX'
ARG JDKVER=17
ARG JDKVENDOR=openjdk

FROM jdk-${JDKVENDOR}-`${JDKVER}${IMAGESUFFIX}${RELEASE}'


RUN apt-get update && apt-get install -y wget procps python3 numactl nmap libssl-dev findutils ethtool \
    dnsutils netcat net-tools && apt-get clean

ARG BASE_DIR=/opt
WORKDIR ${BASE_DIR}
ENV BASE_DIR=${BASE_DIR}


ENV JAVA_HOME=${JDK_INSTALL_DIR}/"${JDKVER}"/ \
  JRE_HOME=${JDK_INSTALL_DIR}/"${JDKVER}"/jre/ \
  PATH=${JDK_INSTALL_DIR}/"${JDKVER}"/bin:$PATH:${JDK_INSTALL_DIR}/"${JDKVER}"/jre/bin

# Prepare Kafka
ARG KAFKA_VER=3.2.0
ARG SCALA_VER=2.12
ARG KAFKA_FILE_NAME=kafka_${SCALA_VER}-${KAFKA_VER}.tgz
ARG KAFKA_PKG=https://archive.apache.org/dist/kafka/${KAFKA_VER}/${KAFKA_FILE_NAME}
ARG SCALA_PKG=https://archive.apache.org/dist/kafka/${KAFKA_VER}/${KAFKA_FILE_NAME}
ARG KAFKA_DIR=${BASE_DIR}/kafka_${SCALA_VER}-${KAFKA_VER}
RUN wget ${KAFKA_PKG} \
    && tar xzf ${KAFKA_FILE_NAME} \
    && rm ${KAFKA_FILE_NAME}

ENV KAFKA_SERVER_CONFIG=${KAFKA_DIR}/config/server.properties
ENV KAFKA_HOME=${KAFKA_DIR}
ENV PATH=$PATH:${KAFKA_HOME}/bin

# Prepare Encryption
ENV PASSWD=test1234
ARG STORE_PASSWORD=${PASSWD}
ARG KEY_PASSWORD=${PASSWD}
ARG D_NAME="CN=localhost, OU=test, O=test, L=xx, ST=xx, C=localhost"
ARG DAYS_VALID=365
RUN mkdir -p ca && \
    cd ca && \
    keytool -keystore kafka.server.keystore.jks -alias localhost -validity ${DAYS_VALID} -genkey -keyalg RSA -storepass ${STORE_PASSWORD} -keypass ${KEY_PASSWORD} -dname "${D_NAME}" && \
    openssl req -new -x509 -keyout ca-key -out ca-cert -days ${DAYS_VALID} -passin pass:${PASSWD} -passout pass:${PASSWD} -subj "/C=CN/ST=xx/L=xx/O=xx/CN=localhost" && \
    keytool -keystore kafka.server.truststore.jks -alias CARoot -import -file ca-cert -storepass ${STORE_PASSWORD} -keypass ${KEY_PASSWORD} -noprompt && \
    keytool -keystore kafka.client.truststore.jks -alias CARoot -import -file ca-cert -storepass ${STORE_PASSWORD} -noprompt && \
    keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file server.cert-file -storepass ${STORE_PASSWORD} -keypass ${KEY_PASSWORD} -noprompt && \
    openssl x509 -req -CA ca-cert -CAkey ca-key -in server.cert-file -out server.cert-file-signed -days ${DAYS_VALID} -CAcreateserial -passin pass:${PASSWD} && \
    keytool -keystore kafka.server.keystore.jks -alias CARoot -import -file ca-cert -storepass ${STORE_PASSWORD} -keypass ${KEY_PASSWORD} -noprompt && \
    keytool -keystore kafka.server.keystore.jks -alias localhost -import -file server.cert-file-signed -storepass ${STORE_PASSWORD} -keypass ${KEY_PASSWORD} -noprompt && \
    chmod +x *

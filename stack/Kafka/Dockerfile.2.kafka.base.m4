changecom(`@')
# STACK-base
changecom(`#')

ARG OS_VER=22.04
ARG OS_IMAGE=ubuntu
FROM ${OS_IMAGE}:${OS_VER}

RUN apt-get update && apt-get install -y wget procps python3 numactl nmap libssl-dev findutils ethtool dnsutils netcat net-tools

ARG BASE_DIR=/opt
WORKDIR ${BASE_DIR}
ENV BASE_DIR=${BASE_DIR}

# Can be overrided when building image
ARG JDKARCH=x86
ARG JDKVER=17
# JDK17
ARG OPENJDK17_VER=17.0.3_7
ARG OPENJDK17_DIR=jdk-17.0.3+7
ARG OPENJDK17_FILE_NAME=OpenJDK17U-jdk_${JDKARCH}_linux_hotspot_${OPENJDK17_VER}.tar.gz
ARG OPENJDK17_PKG=https://github.com/adoptium/temurin17-binaries/releases/download/${OPENJDK17_DIR}/${OPENJDK17_FILE_NAME}
# JDK11
ARG OPENJDK11_VER=11.0.15_10
ARG OPENJDK11_DIR=jdk-11.0.15+10
ARG OPENJDK11_FILE_NAME=OpenJDK11U-jdk_${JDKARCH}_linux_hotspot_${OPENJDK11_VER}.tar.gz
ARG OPENJDK11_PKG=https://github.com/adoptium/temurin11-binaries/releases/download/${OPENJDK11_DIR}/${OPENJDK11_FILE_NAME}
# JDK8
ARG OPENJDK8_VER=8u332b09
ARG OPENJDK8_DIR=jdk8u332-b09
ARG OPENJDK8_FILE_NAME=OpenJDK8U-jdk_${JDKARCH}_linux_hotspot_${OPENJDK8_VER}.tar.gz
ARG OPENJDK8_PKG=https://github.com/adoptium/temurin8-binaries/releases/download/${OPENJDK8_DIR}/${OPENJDK8_FILE_NAME}
# Prepare JDK
RUN OPENJDK_FILE_NAME=$(eval echo \$OPENJDK${JDKVER}_FILE_NAME) \
    && OPENJDK_PKG=$(eval echo \$OPENJDK${JDKVER}_PKG) \
    && OPENJDK_DIR=${BASE_DIR}/$(eval echo \$OPENJDK${JDKVER}_DIR) \
    && wget ${OPENJDK_PKG} \
    && tar xzf ${OPENJDK_FILE_NAME} \
    && rm ${OPENJDK_FILE_NAME} \
    && ln -s ${OPENJDK_DIR} ${BASE_DIR}/jdk \
    && cd ${OPENJDK_DIR} \
    && update-alternatives --install /usr/bin/java java ${OPENJDK_DIR}/bin/java 2 \
    && update-alternatives --install /usr/bin/jar jar ${OPENJDK_DIR}/bin/jar 2 \
    && update-alternatives --install /usr/bin/javac javac ${OPENJDK_DIR}/bin/javac 2 \
    && update-alternatives --set jar ${OPENJDK_DIR}/bin/jar \
    && update-alternatives --set javac ${OPENJDK_DIR}/bin/javac

ENV JAVA_HOME=${BASE_DIR}/jdk
ENV JRE_HOME=${JAVA_HOME}/jre
ENV PATH=$PATH:${JAVA_HOME}/bin:${JAVA_HOME}/jre/bin

# Prepare Kafka
ARG KAFKA_VER=3.2.0
ARG KAFKA_FILE_NAME=kafka_2.12-${KAFKA_VER}.tgz
ARG KAFKA_PKG=https://archive.apache.org/dist/kafka/${KAFKA_VER}/${KAFKA_FILE_NAME}
ARG KAFKA_DIR=${BASE_DIR}/kafka_2.12-${KAFKA_VER}
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

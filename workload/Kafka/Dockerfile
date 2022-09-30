# kafka-client

# Copyright (c) 2022 Intel Corporation
# SPDX-License-Identifier: Apache License 2.0

ARG OS_VER=8.6
ARG OS_IMAGE=rockylinux
FROM ${OS_IMAGE}:${OS_VER}

RUN yum -y install wget procps gcc make zlib-devel
RUN yum update -y && yum upgrade -y

ENV BASE_DIR=/opt
WORKDIR ${BASE_DIR}

# Prepare python3
ARG PYTHON_VER=3.10.2
ARG PYTHON_FILE_NAME=Python-${PYTHON_VER}.tgz
ARG PYTHON_PACKAGE=http://www.python.org/ftp/python/3.10.2/${PYTHON_FILE_NAME}
ARG PYTHON_DIR=${BASE_DIR}/Python-${PYTHON_VER}
RUN wget ${PYTHON_PACKAGE} \
    && tar -zxvf ${PYTHON_FILE_NAME} \
    && rm ${PYTHON_FILE_NAME} \
    && cd ${PYTHON_DIR} \
    && ./configure --enable-optimizations \
    && make altinstall \
    && ln -s /usr/local/bin/python3.10 /usr/bin/python3 \
    && rm -rf ${PYTHON_DIR}

# Prepare JDK
ARG OPENJDK_VER=17.0.1
ARG OPENJDK_FILE_NAME=openjdk-${OPENJDK_VER}_linux-x64_bin.tar.gz
ARG OPENJDK_PKG=http://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/${OPENJDK_FILE_NAME}
RUN wget ${OPENJDK_PKG} \
    && tar xzf ${OPENJDK_FILE_NAME} \
    && rm ${OPENJDK_FILE_NAME} \
    && cd ${BASE_DIR}/jdk-${OPENJDK_VER} \
    && update-alternatives --install /usr/bin/java java ${BASE_DIR}/jdk-${OPENJDK_VER}/bin/java 2 \
    && update-alternatives --install /usr/bin/jar jar ${BASE_DIR}/jdk-${OPENJDK_VER}/bin/jar 2 \
    && update-alternatives --install /usr/bin/javac javac ${BASE_DIR}/jdk-${OPENJDK_VER}/bin/javac 2 \
    && update-alternatives --set jar ${BASE_DIR}/jdk-${OPENJDK_VER}/bin/jar \
    && update-alternatives --set javac ${BASE_DIR}/jdk-${OPENJDK_VER}/bin/javac

ENV JAVA_HOME=${BASE_DIR}/jdk-${OPENJDK_VER}/
ENV JRE_HOME=${BASE_DIR}/jdk-${OPENJDK_VER}/jre/
ENV PATH $PATH:${BASE_DIR}/jdk-${OPENJDK_VER}/bin:${BASE_DIR}/jdk-${OPENJDK_VER}/jre/bin

# Prepare Kafka
ENV KAFKA_VER=kafka_2.12-2.8.1
ARG KAFKA_FILE_NAME=${KAFKA_VER}.tgz
ARG KAFKA_PKG=http://archive.apache.org/dist/kafka/2.8.1/${KAFKA_VER}.tgz
RUN wget ${KAFKA_PKG} \
    && tar xzf ${BASE_DIR}/${KAFKA_VER}.tgz \
    && rm ${KAFKA_FILE_NAME}

ENV PATH $PATH:${BASE_DIR}/${KAFKA_VER}/bin

# Copy helper script and testcases
COPY run_test.sh ${BASE_DIR}
COPY start_test.py ${BASE_DIR}
ENV PATH $PATH:${BASE_DIR}

RUN  mkfifo /export-logs

CMD ( ./run_test.sh; echo $? > status) 2>&1 | tee ${IDENTIFIER}_std.logs && \
cat log* > ${IDENTIFIER}_output.logs && \
sync status ${IDENTIFIER}_output.logs ${IDENTIFIER}_std.logs && \
tar cf /export-logs status ${IDENTIFIER}_output.logs ${IDENTIFIER}_std.logs && \
sleep infinity

# doris-benchmark

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_VER=9.3
ARG OS_IMAGE=rockylinux
FROM ${OS_IMAGE}:${OS_VER}

# Define versions explicitly
ARG MYSQL_VER=80
ARG MYSQL_PKG=mysql${MYSQL_VER}-community-release-el9-1.noarch.rpm

# Prepare Doris
ARG DORIS_VER=3.0
ARG DORIS_SUB=3.0.5
ARG DORIS_SUB_VER=3.0.5-rc01
ARG DORIS_DIR=apache-doris-${DORIS_SUB}-src
ARG DORIS_FILE_NAME=${DORIS_DIR}.tar.gz
ARG DORIS_PKG=https://downloads.apache.org/doris/${DORIS_VER}/${DORIS_SUB_VER}/${DORIS_FILE_NAME}

# Install dependencies
RUN yum -y install yum-utils gcc wget make jq bind-utils \
    && rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 \
    && curl -sSLO https://dev.mysql.com/get/${MYSQL_PKG} \
    && rpm -Uvh ${MYSQL_PKG} && rm ${MYSQL_PKG} \
    && yum -y install mysql-community-server \
    && yum clean all

# Download and extract Doris source
RUN cd /home && curl -sSLO ${DORIS_PKG} && tar zxf ${DORIS_FILE_NAME} \
    && mv ${DORIS_DIR} apache-doris-src && rm ${DORIS_FILE_NAME} \
    && cd apache-doris-src/tools/ssb-tools/bin/ && sh build-ssb-dbgen.sh

# Copy benchmark scripts
COPY script/* /home/apache-doris-src/
WORKDIR /home/apache-doris-src

# Ensure scripts are executable
RUN chmod +x /home/apache-doris-src/*.sh

# Create a named pipe for log export
RUN mkfifo /export-logs

CMD (./run_test.sh; echo $? > status) 2>&1 | tee doris_benchmark.log && \
    sync status doris_benchmark.log && \
    tar cf /export-logs status doris_benchmark.log && \
    sleep infinity


# doris-be

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Use Rocky Linux 9.3 as base image
ARG OS_VER=9.3
ARG OS_IMAGE=rockylinux
FROM ${OS_IMAGE}:${OS_VER}

# ===== Install basic dependencies and JDK 21 =====
ARG JDKARCH=x64
ARG JDKVER=17
ARG OPENJDK17_VER=17.0.15_6
ARG OPENJDK17_DIR=jdk-17.0.15+6
ARG OPENJDK17_FILE_NAME=OpenJDK17U-jdk_${JDKARCH}_linux_hotspot_${OPENJDK17_VER}.tar.gz
ARG OPENJDK17_PKG=https://github.com/adoptium/temurin17-binaries/releases/download/${OPENJDK17_DIR}/${OPENJDK17_FILE_NAME}

RUN dnf -y update && \
    dnf -y install wget tar bind-utils unzip python3 which iproute xz \
        --setopt=install_weak_deps=False && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ## install OpenJDK 17
    cd /opt && \
    curl -sSLO ${OPENJDK17_PKG} && \
    tar xzf ${OPENJDK17_FILE_NAME} && \
    rm ${OPENJDK17_FILE_NAME} && \
    ln -s ${OPENJDK17_DIR} /opt/jdk && \
    update-alternatives --install /usr/bin/java java /opt/${OPENJDK17_DIR}/bin/java 2 && \
    update-alternatives --install /usr/bin/jar jar /opt/${OPENJDK17_DIR}/bin/jar 2 && \
    update-alternatives --install /usr/bin/javac javac /opt/${OPENJDK17_DIR}/bin/javac 2 && \
    update-alternatives --set jar /opt/${OPENJDK17_DIR}/bin/jar && \
    update-alternatives --set javac /opt/${OPENJDK17_DIR}/bin/javac && \
    dnf clean all && rm -rf /var/cache/dnf

ENV JAVA_HOME=/opt/jdk
ENV PATH=$JAVA_HOME/bin:$PATH

# Set working directory for Doris
WORKDIR /home

# Download and extract prebuilt Doris binary (BE)
ARG DORIS_VERSION=3.0.5
ARG DORIS_BIN_URL=https://apache-doris-releases.oss-accelerate.aliyuncs.com/apache-doris-${DORIS_VERSION}-bin-x64.tar.gz
RUN wget ${DORIS_BIN_URL} -O doris.tar.gz && \
    tar -xzf doris.tar.gz && \
    rm doris.tar.gz && \
    mv apache-doris-* apache-doris

RUN mkdir -p /home/apache-doris-be && \
    mv /home/apache-doris/be/* /home/apache-doris-be/ && \
    rm -rf /home/apache-doris

# Copy startup local scripts
COPY script/* /home/apache-doris-be/
WORKDIR /home/apache-doris-be

# Default command to start Doris BE
CMD ./start_doris_be.sh && sleep infinity
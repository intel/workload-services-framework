changecom(`@')
# jdk-defn(`JDK_VENDOR')-defn(`JDK_VERSION')-ubuntu24
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_VER=24.04
ARG OS_IMAGE=ubuntu

FROM `${OS_IMAGE}:${OS_VER}'

RUN apt-get update && apt-get install -y curl libreadline-dev libnuma-dev gettext && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG JDKARCH=JDK_ARCH
ARG JDK_VER=JDK_VERSION
ARG JDK_PKG=JDK_URL

ARG JDK_INSTALL_DIR=/opt/jdk

WORKDIR ${JDK_INSTALL_DIR}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir ${JDK_VER} && \
  curl -L -o - ${JDK_PKG} | tar xfz - -C ${JDK_VER} --strip-components=1

RUN update-alternatives --install /usr/bin/java java ${JDK_INSTALL_DIR}/${JDK_VER}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${JDK_INSTALL_DIR}/${JDK_VER}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${JDK_INSTALL_DIR}/${JDK_VER}/bin/javac 2 && \
  update-alternatives --set jar ${JDK_INSTALL_DIR}/${JDK_VER}/bin/jar && \
  update-alternatives --set javac ${JDK_INSTALL_DIR}/${JDK_VER}/bin/javac

ENV JDK_VER=JDK_VERSION \
  JAVA_HOME=${JDK_INSTALL_DIR}/${JDK_VER}/ \
  JRE_HOME=${JDK_INSTALL_DIR}/${JDK_VER}/jre/ \
  PATH=${JDK_INSTALL_DIR}/${JDK_VER}/bin:$PATH:${JDK_INSTALL_DIR}/${JDK_VER}/jre/bin

WORKDIR /opt/scripts
COPY scripts/environment.sh ./environment.sh
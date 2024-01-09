# trex-base

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_VER=22.04
ARG OS_IMAGE=ubuntu

FROM ${OS_IMAGE}:${OS_VER}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y apt-utils kmod wget build-essential \
    libffi-dev zlib1g-dev pciutils iproute2 psmisc

ARG RESSL_VER="2.7.4"
ARG RESSL_PACKAGE=https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${RESSL_VER}.tar.gz
RUN cd / && \
    wget -O - ${RESSL_PACKAGE} | tar xzf - && \
    cd libressl-*  && \
    ./configure --prefix=/usr/local/ && \
    make install && \
    ldconfig -v

ARG PYTHON_VER="3.8.0"
ARG PYTHON_PACKAGE=https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz
RUN cd / && \
    wget -O - ${PYTHON_PACKAGE} | tar xfJ - && \
    cd Python-*  && \
    sed -i 's/#SSL=\/usr\/local\/ssl/SSL=\/usr\/local/g' ./Modules/Setup && \
    sed -i '211,213s/#//g' ./Modules/Setup && \
    ./configure && \
    make && \
    make install && \
    python3 -m pip install -U pip setuptools && \
    python3 -m pip install --upgrade cryptography && \
    ln -s /usr/local/bin/python3 /usr/bin/python3

# ARG TREX_VER=2.97
ARG TREX_VER=3.00
ARG TREX_PACKAGE=https://trex-tgn.cisco.com/trex/release/v${TREX_VER}.tar.gz

# Download and install trex to /opt/trex
RUN wget --no-check-certificate ${TREX_PACKAGE} -P /tmp \
    && mkdir /opt/trex-v${TREX_VER} \
    && ln -s /opt/trex-v${TREX_VER} /opt/trex \
    && tar xzf /tmp/v${TREX_VER}.tar.gz -C /opt/trex --strip-components 1 \
    && rm /tmp/v${TREX_VER}.tar.gz \
    && chown -R root: /opt/trex*

# Workaround trex known issue that vfio-pci kernel driver not found
# By default trex loading drivers in /proc/modules where vfio-pci can not be found
# Since vfio-pci has been built in kernel 
# vfio-pci can be found by this command cat /lib/modules/$(uname -r)/modules.builtin | grep vfio
RUN sed -i 's/loaded_modules = \[\]/loaded_modules = ["vfio-pci"]/' /opt/trex/dpdk_nic_bind.py

# Unarchive trex_client for possible api invocation
RUN cd /opt/trex \
    && tar xzf trex_client_v${TREX_VER}.tar.gz

# Install network tools
RUN apt-get update && \
    apt-get install -y \
    vim \
    net-tools \
    lsof \
    dnsutils \
    iputils-ping

WORKDIR /opt/trex

RUN ln -sf /usr/local/bin/python3 /usr/local/bin/python

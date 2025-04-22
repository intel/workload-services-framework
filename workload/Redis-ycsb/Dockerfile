# redis-ycsb-server

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_VER=9.3
ARG OS_IMAGE=rockylinux
FROM ${OS_IMAGE}:${OS_VER}

# Dependencies
ENV TZ=America/Los_Angeles
RUN yum install -y findutils wget gcc gcc-c++ make zlib-devel autoconf automake pcre-devel pcre2-devel libevent-devel pkgconf openssl-devel openssl zip unzip numactl procps-ng

WORKDIR /home

# Redis
ARG REDIS_VER=6.2.1
ARG REDIS_PACKAGE=https://download.redis.io/releases/redis-${REDIS_VER}.tar.gz
RUN wget ${REDIS_PACKAGE} -O redis.tgz && tar -zxvf redis.tgz
RUN cd redis-${REDIS_VER} && make install
RUN mkdir /home/redis-${REDIS_VER}/rdb/

# Add script
WORKDIR /redis
RUN mkdir redis-conf
#copy redis_conf.conf to /redis/redis-conf/
COPY redis_conf.conf /redis/redis-conf/ 
COPY run_server.sh .
RUN chmod +x run_server.sh

RUN mkfifo /export-logs

CMD (/redis/run_server.sh; echo $? > status) 2>&1 | tee run.log && \
    tar cf /export-logs status run.log && sleep infinity;
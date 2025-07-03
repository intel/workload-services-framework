changecom(`@')dnl
# ycsb-ifelse(regexp(PLATFORM, ARMv[0-9]),-1,`amd64',`arm64')-patsubst(patsubst(WORKLOAD,`ycsb_', `'),`_',`-')
define(`generate_mongodb_base_image',ifelse(regexp(PLATFORM, ARMv[0-9]),-1,`amd64',`arm64')-patsubst(patsubst(WORKLOAD,`ycsb_', `'),`_',`-'))dnl
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
changecom(`#')dnl

ifelse(regexp(PLATFORM,ARMv[0-9]),-1,
`ARG MONGODB_BASE_IMAGE=generate_mongodb_base_image',
`ARG MONGODB_BASE_IMAGE=generate_mongodb_base_image-arm64')
FROM ${MONGODB_BASE_IMAGE}RELEASE

WORKDIR /usr/src/mongodb/bin

ifelse(regexp(WORKLOAD, redhat$),-1,`RUN apt update && apt install -y iproute2 ethtool kmod redis sudo stress-ng bc numactl',`RUN yum update -y && yum -y install gcc openssl-devel bzip2-devel automake autoconf libtool make net-snmp wget nc')

COPY script/mongodb_config.sh .
COPY conf/mongod.conf .
COPY script/stress-ng.sh .
COPY script/log_to_redis.sh .

RUN chmod +x mongodb_config.sh stress-ng.sh log_to_redis.sh

RUN mkfifo /export-logs
# Configure, run MongoDB, fork it and append logs to redis
CMD (./mongodb_config.sh; echo $? > status) 2>&1 | tee mongodb_config.logs \
    && tar cf /export-logs status mongodb_config.logs mongod.conf \
    && tail -f "/var/lib/mongo/mongo-$server_index.log" | ./log_to_redis.sh | redis-cli -h config-center -p $m_config_center_port --pipe \
    && rm -rf /var/tmp/MONGOIAATAG \
    && sleep infinity

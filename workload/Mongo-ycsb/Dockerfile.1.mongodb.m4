# ycsb-amd64-mongodb604-base

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG MONGODB_BASE_IMAGE=amd64-mongodb604-base
FROM ${MONGODB_BASE_IMAGE}RELEASE

RUN apt update && apt install -y iproute2 ethtool sudo numactl

COPY script/mongodb_config.sh /usr/src/mongodb/bin
COPY conf/mongod.conf /usr/src/mongodb/bin

RUN chmod +x /usr/src/mongodb/bin/mongodb_config.sh

WORKDIR /usr/src/mongodb/bin

RUN mkdir mongod.log
RUN mkfifo /export-logs
CMD (./mongodb_config.sh; echo $? > status) 2>&1 | tee mongodb_config.logs \
    && mv /var/lib/mongo/mongo-*.log ./mongod.log \
    && tar cf /export-logs status mongodb_config.logs mongod.log \
    && sleep infinity

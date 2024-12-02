# syntax=docker/dockerfile:1
# unixbench

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# The last of the first two comment lines defines the docker image name. If the comment
# line starts with #, then the image will be pushed to the docker registry if defined.
# If comment line starts with ##, then the image is a local image and will not be pushed.
# See doc/developer-guide/component-design/dockerfile.md for full documentation.

# You can use any base OS in your workload. Popular choices are ubuntu, debian and alpine.
# Declare the OS ingredient as OS_VER and OS_IMAGE.

ARG OS_VER="24.04"
ARG OS_IMAGE="ubuntu"
FROM ${OS_IMAGE}:${OS_VER}

RUN echo ${http_proxy}
RUN echo ${https_proxy}

RUN apt update -y && \
    apt install -y wget gcc make perl procps numactl git language-pack-en language-pack-de

ARG UNIX_BENCH_REPO=https://github.com/kdlucas/byte-unixbench.git
ARG UNIX_BENCH_VER=master
RUN git clone --recursive $UNIX_BENCH_REPO -b $UNIX_BENCH_VER


COPY run_test.sh /

# This is the standarized logs collection sequence. In this example, the logs is the
# standard output but the logs can contain anything relevant to the workload execution.
# The logs are archived together with the workload exit code to a fifo /export-logs.
# Then sleep infinity for logs retrievial.
RUN  mkfifo /export-logs
CMD  (./run_test.sh; echo $? > status) 2>&1 | tee output.logs && \
     tar cf /export-logs status output.logs && \
     sleep infinity

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-tf_int8_avx_multi_4_gated}

PLATFORM=${PLATFORM:-ICX}
WORKLOAD=${WORKLOAD:-malconv}
FRAMEWORK=$(echo ${OPTION}|cut -d_ -f1)
PRECISION=$(echo ${OPTION}|cut -d_ -f2)
ISA=$(echo ${OPTION}|cut -d_ -f3)
MODE=$(echo ${OPTION}|cut -d_ -f4)
CORES=$(echo ${OPTION}|cut -d_ -f5)
TAG=$(echo ${OPTION}|cut -d_ -f6)

if [ ${#TAG} -eq 0 ]; then
    TAG=none
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(PLATFORM WORKLOAD FRAMEWORK PRECISION ISA MODE CORES TAG)

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile"
# avoid privileged for numactl, --cap-add SYS_NICE is
DOCKER_OPTIONS="--cap-add SYS_NICE -e FRAMEWORK=${FRAMEWORK} -e PRECISION=${PRECISION} -e ISA=${ISA} -e MODE=${MODE} -e CORES=${CORES} -e TAG=${TAG}"

# Kubernetes Setting
RECONFIG_OPTIONS="-DK_WORKLOAD=${WORKLOAD} -DK_FRAMEWORK=${FRAMEWORK} -DK_PRECISION=${PRECISION} -DK_ISA=${ISA} -DK_MODE=${MODE} -DK_CORES=${CORES} -DK_TAG=${TAG}"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
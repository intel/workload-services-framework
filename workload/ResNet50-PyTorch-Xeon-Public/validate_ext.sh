#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_throughput_avx_fp32_gated}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-resnet50_pytorch_xeon_public}

TOPOLOGY=${TOPOLOGY:-resnet50}
FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f5)
PRECISION=$(echo ${OPTION}|cut -d_ -f3)_$(echo ${OPTION}|cut -d_ -f4)
DATA_TYPE=${DATA_TYPE:-dummy}
WARMUP_STEPS=${WARMUP_STEPS:-20}
STEPS=${STEPS:-100}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-}
BATCH_SIZE=${BATCH_SIZE:-1}
WEIGHT_SHARING=${WEIGHT_SHARING:-False}
VERBOSE=${VERBOSE:-0}
CUSTOMER_ENV=${CUSTOMER_ENV:-}
TRAIN_EPOCH=${TRAIN_EPOCH:-}
DISTRIBUTED=${DISTRIBUTED:-False}
CCL_WORKER=${CCL_WORKER:-4}
TORCH_TYPE=${TORCH_TYPE:-IPEX}

if [ "$MODE" == "accuracy" ]; then
    BATCH_SIZE=${BATCH_SIZE:-100}
    DATA_TYPE=real
fi

if [ "$CASE_TYPE" == "pkm" ]; then
    EVENT_TRACE_PARAMS="roi,Evaluating RESNET: ,Complete..."
fi

function k8s_settings() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="-DK_$i=\$$i"
        else
            RET="${RET} -DK_$i=\$$i"
        fi
    done
    echo "$RET"
}

function docker_settings() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="-e $i=\$$i"
        else
            RET="${RET} -e $i=\$$i"
        fi
    done
    echo "$RET"
}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.intel-public-inference_24.04";


ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE WARMUP_STEPS STEPS DATA_TYPE CORES_PER_INSTANCE CASE_TYPE WEIGHT_SHARING VERBOSE CUSTOMER_ENV TRAIN_EPOCH DISTRIBUTED CCL_WORKER TORCH_TYPE"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DK_DOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=resnet50-pytorch-xeon-public-benchmark"

. "$DIR/../../script/validate.sh"

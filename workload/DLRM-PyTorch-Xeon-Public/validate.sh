#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_throughput_avx_fp32_gated}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-dlrm_pytorch_xeon_public}
TOPOLOGY=${TOPOLOGY:-dlrm}
FUNCTION=$(echo ${OPTION}|cut -d_ -f5)
MODE=$(echo ${OPTION}|cut -d_ -f6|cut -d- -f1)
PRECISION=$(echo ${OPTION}|cut -d_ -f7)_$(echo ${OPTION}|cut -d_ -f8)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f9)
DATA_TYPE=${DATA_TYPE:-real}
WARMUP_STEPS=${WARMUP_STEPS:-200}
STEPS=${STEPS:-200} # Warmup steps for inference is 100
TRAIN_EPOCH=${TRAIN_EPOCH:-10}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE}
INSTANCE_NUMBER=${INSTANCE_NUMBER}
BATCH_SIZE=${BATCH_SIZE:-1}
WEIGHT_SHARING=${WEIGHT_SHARING:-True}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}
CUSTOMER_ENV=${CUSTOMER_ENV:-}

if [ "$FUNCTION" == "training" ]; then
    WEIGHT_SHARING=False
    BATCH_SIZE=128 # Do not set BATCH_SIZE too small for training
    STEPS=2000 # Warmup steps for training is 1000
    DATA_TYPE=real
    if [ "$MODE" == "throughput" ]; then
        DISTRIBUTED=${DISTRIBUTED:-False}
        CCL_WORKER_COUNT=${CCL_WORKER_COUNT:-4}
    fi
elif [ "$MODE" == "accuracy" ]; then
    WEIGHT_SHARING=False
    STEPS=2000
    DATA_TYPE=real
fi

if [ "$CASE_TYPE" == "pkm" ]; then
    EVENT_TRACE_PARAMS="time,180,60"
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
if [[ "$WORKLOAD" = *pdt ]]; then
    DOCKER_IMAGE="$DIR/pdt/Dockerfile.1.${FUNCTION}"
elif [ "$MODE" == "accuracy" ] && [ "$FUNCTION" == "inference" ]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.$FUNCTION.$MODE"
else
    DOCKER_IMAGE="$DIR/Dockerfile.1.$FUNCTION"
fi
if [[ -e "$DIR/build_ext.sh" ]]; then
    DOCKER_IMAGE="${DOCKER_IMAGE}_24.04"
fi
ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE WARMUP_STEPS STEPS DATA_TYPE CORES_PER_INSTANCE INSTANCE_NUMBER DISTRIBUTED CCL_WORKER_COUNT TRAIN_EPOCH CASE_TYPE WEIGHT_SHARING ONEDNN_VERBOSE CUSTOMER_ENV"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged $DOCKER_ARGS --shm-size=8g"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DK_DOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=dlrm-pytorch-xeon-public-benchmark"

. "$DIR/../../script/validate.sh"

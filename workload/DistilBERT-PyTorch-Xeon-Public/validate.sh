#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_throughput_avx_fp32_gated}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-distilbert_pytorch_xeon_public}

TOPOLOGY="distilbert"
FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
PRECISION=$(echo ${OPTION}|cut -d_ -f3-4)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f5)
DATA_TYPE=${DATA_TYPE:-real}
STEPS=${STEPS:-100}

if [ "$MODE" == "accuracy" ]; then
    BATCH_SIZE=${BATCH_SIZE:-100}
else
    BATCH_SIZE=${BATCH_SIZE:-1}
fi

CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-}
INSTANCE_NUMBER=${INSTANCE_NUMBER:-}
MAX_SEQ_LENGTH=${MAX_SEQ_LENGTH:-128}

if [ "$MODE" == "latency" ]; then
    WEIGHT_SHARING=${WEIGHT_SHARING:-True}
else 
    WEIGHT_SHARING=${WEIGHT_SHARING:-False}
fi

ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}
MAX_CPU_ISA=${MAX_CPU_ISA:-}
CUSTOMER_ENV=${CUSTOMER_ENV:-"ONEDNN_VERBOSE=0"}

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

EVENT_TRACE_PARAMS="roi,Running Evaluation,Finish case topology"

WARMUP_STEPS=$(($STEPS/10))

# Docker Setting
if [[ "$WORKLOAD" = *pdt ]]; then
    DOCKER_IMAGE="$DIR/pdt/Dockerfile.1.intel-public"
else 
    DOCKER_IMAGE="$DIR/Dockerfile.1.intel-public_24.04"
fi

ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS DATA_TYPE CORES_PER_INSTANCE INSTANCE_NUMBER WEIGHT_SHARING TRAIN_EPOCHS CASE_TYPE MAX_SEQ_LENGTH ONEDNN_VERBOSE MAX_CPU_ISA CUSTOMER_ENV WARMUP_STEPS"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DK_DOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=distilbert-pytorch-xeon-public"

. "$DIR/../../script/validate.sh"

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_latency_bfloat16_pkm}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-stablediffusion_pytorch_xeon_public}

FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
PRECISION=$(echo ${OPTION}|cut -d_ -f3)
BATCH_SIZE=${BATCH_SIZE:-1}
WARMUP_STEPS=${WARMUP_STEPS:-5}
STEPS=${STEPS:-10}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:--1}
NUMA_NODES_USE=${NUMA_NODES_USE:-0}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}

TORCH_TYPE=${TORCH_TYPE:-"COMPILE-IPEX"}
USE_JEMALLOC=${USE_JEMALLOC:-True}
USE_TCMALLOC=${USE_TCMALLOC:-False}
MODEL_NAME=${MODEL_NAME:-"stabilityai/stable-diffusion-2-1"}

IMAGE_WIDTH=${IMAGE_WIDTH:-512}
IMAGE_HEIGHT=${IMAGE_HEIGHT:-512}

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

#EVENT TRACE PARAMS
EVENT_TRACE_PARAMS="roi,start benchmark,end benchmark"

# Docker Setting
DNOISE_STEPS=${DNOISE_STEPS:-5}
DOCKER_IMAGE="$DIR/Dockerfile.1.sd"
MODEL_PATH=${MODEL_PATH:-"/opt/dataset/stable-diffusion-2-1/hub"}

MODEL_SUBPATH=$(echo ${MODEL_PATH}| sed 's/\/opt\/dataset\///g; s/\//-/g'| tr '[:lower:]' '[:upper:]')

ALL_KEYS="MODE WORKLOAD TOPOLOGY PRECISION FUNCTION DATA_TYPE BATCH_SIZE CORES_PER_INSTANCE NUMA_NODES_USE ONEDNN_VERBOSE WARMUP_STEPS STEPS \
        USE_JEMALLOC USE_TCMALLOC MODEL_NAME TORCH_TYPE IMAGE_WIDTH IMAGE_HEIGHT DNOISE_STEPS MODEL_PATH MODEL_SUBPATH"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)

DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS=" --privileged $DOCKER_ARGS -v ${MODEL_PATH}:/root/.cache/huggingface/hub"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=stablediffusion-pytorch-xeon-public"

. "$DIR/../../script/validate.sh"

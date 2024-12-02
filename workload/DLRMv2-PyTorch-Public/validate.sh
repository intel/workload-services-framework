#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_throughput_amx_bfloat16_gated}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-dlrmv2-pytorch-public}

TOPOLOGY="DLRM-V2"
FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
PRECISION=$(echo ${OPTION}|cut -d_ -f3-4)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f6)
DATA_TYPE=${DATA_TYPE:-dummy}
FUNCTION=${FUNCTION:-inference}
WARMUP_STEPS=${WARMUP_STEPS:-10}
STEPS=${STEPS:-100}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}
USE_JEMALLOC=${USE_JEMALLOC:-True}
USE_TCMALLOC=${USE_TCMALLOC:-False}
NUMA_NODES_USE=${NUMA_NODES_USE:-all}
TORCH_TYPE=${TORCH_TYPE:-"IPEX"}

VM_IMAGE_NAME=${VM_IMAGE_NAME:-wsf-dataset-ai-dlrmv2-pytorch}
DATASET_MODEL_PATH_HOST="/opt/dataset/dlrmv2-pytorch/DLRM-V2"
DATASET_MODEL_PATH_CONTAINER="/home/dataset/pytorch/DLRM-V2"
FULL_PLATFORM_NAME=$2
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:--1}

if [ "$MODE" == "accuracy" ]; then
    INSTANCE_MODE=${INSTANCE_MODE:-fixed}
    BATCH_SIZE=${BATCH_SIZE:--1}
    DATA_TYPE=real
else
    INSTANCE_MODE=${INSTANCE_MODE:-flex}
    BATCH_SIZE=${BATCH_SIZE:-16}
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

TARGET_PLATFORM=${PLATFORM}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

. "$DIR/../../script/sut-info.sh" --csp-only
[ -z "$SUTINFO_CSP" ] || CSP_NAME=$(echo $SUTINFO_CSP | tr '[:lower:]' '[:upper:]') && export ${CSP_NAME}_WORKER_OS_IMAGE=$VM_IMAGE_NAME

EVENT_TRACE_PARAMS="roi,Start case topology,Finish case topology"

ALL_KEYS="WORKLOAD TARGET_PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS WARMUP_STEPS DATA_TYPE CASE_TYPE INSTANCE_MODE ONEDNN_VERBOSE TORCH_TYPE USE_JEMALLOC USE_TCMALLOC NUMA_NODES_USE DATASET_MODEL_PATH_CONTAINER DATASET_MODEL_PATH_HOST FULL_PLATFORM_NAME CORES_PER_INSTANCE"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged  $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
JOB_FILTER="job-name=dlrmv2-pytorch-public"

if [[ -e "$DIR/build_int.sh" ]]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.base"
else 
    DOCKER_IMAGE="$DIR/Dockerfile.1.base_24.04"
fi

#DOCKER_IMAGE="$DIR/Dockerfile_24.04"
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"
. "$DIR/../../script/validate.sh"

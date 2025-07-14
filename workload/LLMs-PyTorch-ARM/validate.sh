#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-throughput_pkm}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-llms_pytorch_arm}

FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f1)
PRECISION="bfloat16"
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f4)
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-}
INSTANCE_NUMBER=${INSTANCE_NUMBER:-}
DATA_TYPE="real"
BATCH_SIZE=${BATCH_SIZE:-1}
STEPS=${STEPS:-20} 
INPUT_TOKENS=${INPUT_TOKENS:-1024}
OUTPUT_TOKENS=${OUTPUT_TOKENS:-128}
VM_IMAGE_NAME=${VM_IMAGE_NAME:-wsf-dataset-ai-gptj-paiv}
GREEDY=${GREEDY:-False}
NUMA_NODES_USE=${NUMA_NODES_USE:-0}
USE_DEEPSPEED=${USE_DEEPSPEED:-False}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}
RANK_USE=${RANK_USE:-all}
BENCHMARKING_TRACE=${BENCHMARKING_TRACE:-True}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-}
MODEL_NAME=${MODEL_NAME:-meta-llama/Llama-2-7b-chat-hf}
MODEL_PATH=${MODEL_PATH:-}

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

# defult MODEL_PATH
if [[ "${MODEL_NAME}" == *"gpt-j"* ]]; then
    MODEL_PATH=${MODEL_PATH:-"/opt/dataset/gptj/6b"}
elif [[ "${MODEL_NAME}" == *"Llama-2"* ]]; then
    MODEL_PATH=${MODEL_PATH:-"/opt/dataset/llama2/$(echo ${MODEL_NAME}|cut -d "/" -f2|cut -d "-" -f3)"}
elif [[ "${MODEL_NAME}" == *"Llama-3"* ]]; then
    if  [[ "${MODEL_NAME}" == *"Llama-3.1"* ]]; then
        MODEL_PATH=${MODEL_PATH:-"/opt/dataset/llama31/$(echo ${MODEL_NAME,,}|cut -d "/" -f2|cut -d "-" -f4)"}
    elif  [[ "${MODEL_NAME}" == *"Llama-3.2"* ]]; then
        MODEL_PATH=${MODEL_PATH:-"/opt/dataset/llama32/$(echo ${MODEL_NAME,,}|cut -d "/" -f2|cut -d "-" -f3)"}
    else
        MODEL_PATH=${MODEL_PATH:-"/opt/dataset/llama3/$(echo ${MODEL_NAME,,}|cut -d "/" -f2|cut -d "-" -f4)"}
    fi
else
    LOWER_MODEL_NAME=$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')
    MODEL_PATH=${MODEL_PATH:-"/opt/dataset/$(echo ${LOWER_MODEL_NAME}|cut -d "/" -f2|cut -d "-" -f1)/$(echo ${LOWER_MODEL_NAME}|cut -d "/" -f2|cut -d "-" -f2)"}
fi

. "$DIR/../../script/sut-info.sh" --csp-only
[ -z "$SUTINFO_CSP" ] || CSP_NAME=$(echo $SUTINFO_CSP | tr '[:lower:]' '[:upper:]') && export ${CSP_NAME}_WORKER_OS_IMAGE=$VM_IMAGE_NAME

TARGET_PLATFORM=${PLATFORM}
WARMUP_STEPS=$(($STEPS/10))

MODEL_SUBPATH=$(echo ${MODEL_PATH}| sed 's/\/opt\/dataset\///g; s/\//-/g'| tr '[:lower:]' '[:upper:]')
#EVENT TRACE PARAMS
if [ "${BENCHMARKING_TRACE}" == "True" ]; then
    EVENT_TRACE_PARAMS="roi,Iteration: $WARMUP_STEPS,Iteration: $(($STEPS - 1))"
else
    EVENT_TRACE_PARAMS="roi,Start case topology,Finish case topology"
fi

ALL_KEYS="MODE WORKLOAD PRECISION NUMA_NODES_USE FUNCTION DATA_TYPE BATCH_SIZE INPUT_TOKENS OUTPUT_TOKENS STEPS GREEDY WARMUP_STEPS MODEL_NAME MODEL_PATH USE_DEEPSPEED ONEDNN_VERBOSE TARGET_PLATFORM RANK_USE CORES_PER_INSTANCE MODEL_SUBPATH"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)

# Docker Setting
if [[ -e "$DIR/build.sh" ]]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.inference"
fi

DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")

DEST_DATASET_DIR="/root/.cache/huggingface/hub"
if [[ "${USE_DEEPSPEED}" == "True" ]]; then
    DEST_DATASET_DIR="/dev/shm"
fi

DOCKER_OPTIONS="--network host --privileged $DOCKER_ARGS -v ${MODEL_PATH}:${DEST_DATASET_DIR}"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE} -DK_http_proxy=$http_proxy -DK_https_proxy=$https_proxy"

JOB_FILTER="job-name=llms-pytorch-arm"

. "$DIR/../../script/validate.sh"

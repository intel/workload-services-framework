#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_latency_bfloat16_pkm}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-yolov7_pytorch_public}

TOPOLOGY="lcm"

FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
PRECISION=$(echo ${OPTION}|cut -d_ -f3)
HARDWARE=$(echo ${OPTION}|cut -d_ -f4)
if [ "${MODE}" == "accuracy" ]; then
    BATCH_SIZE=${BATCH_SIZE:-100}
else
    BATCH_SIZE=${BATCH_SIZE:-16}
fi

WARMUP_STEPS=${WARMUP_STEPS:-5}
STEPS=${STEPS:-20}

CORES_PER_INSTANCE=${CORES_PER_INSTANCE:--1}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}
TORCH_TYPE=${TORCH_TYPE:-"COMPILE-IPEX"}
HABANA_VISIBLE_DEVICES=${HABANA_VISIBLE_DEVICES:-"all"}

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

ALL_KEYS="MODE PRECISION BATCH_SIZE CORES_PER_INSTANCE ONEDNN_VERBOSE WARMUP_STEPS STEPS TORCH_TYPE HARDWARE"

DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")

# Docker Setting
DOCKER_IMAGE=yolov7-pytorch-public-${WORKLOAD##*_}
DOCKER_OPTIONS=" --privileged $DOCKER_ARGS --shm-size=4g"


# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=yolov7-pytorch-public"

. "$DIR/../../script/validate.sh"

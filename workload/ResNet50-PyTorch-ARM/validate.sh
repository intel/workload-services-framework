#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-resnet50v15_pytorch_arm}
PLATFORM=${PLATFORM:-ARMv8}
PRECISION=${PRECISION:-FP32}
BATCH_SIZE=${BATCH_SIZE:-1}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-1}
TORCH_MKLDNN_MATMUL_MIN_DIM=${TORCH_MKLDNN_MATMUL_MIN_DIM:-1024}

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


DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"
DOCKER_IMAGE="resnet-pytorch-inference"

ALL_KEYS=" WORKLOAD PLATFORM PRECISION BATCH_SIZE CORES_PER_INSTANCE TORCH_MKLDNN_MATMUL_MIN_DIM"
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")

DOCKER_OPTIONS=" --privileged --shm-size 4g -e JIT_PATCH=jit.script.patch $DOCKER_ARGS"
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"
. "$DIR/../../script/validate.sh"

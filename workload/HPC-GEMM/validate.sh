#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ASM_TYPE=${1:-avx2}
FLOAT_TYPE=${2:-sgemm}
MATH_LIB=${3:-mkl}
MATRIX_SIZE=${4:-4000}
OMP_NUM_THREADS=${5:-0}

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
if [[ $ASM_TYPE == "avx2" ]]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.srf"
else
    DOCKER_IMAGE="$DIR/Dockerfile"
fi

# Workload Setting
ALL_KEYS="MATH_LIB FLOAT_TYPE MATRIX_SIZE OMP_NUM_THREADS" 
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS=" --privileged $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS=" ${K8S_PARAMS} -DK_DOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"
. "$DIR/../../script/validate.sh"
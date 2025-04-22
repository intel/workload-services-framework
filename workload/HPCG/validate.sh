#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-hpcg}
TESTCASE=${TESTCASE:-single_node_gated}
CONFIG=${2:-generic}
DIMENSION=${3:-104}
X_DIMENSION=$DIMENSION
Y_DIMENSION=$DIMENSION
Z_DIMENSION=$DIMENSION
RUN_SECONDS=${4:-60}
PROCESS_PER_NODE=${5:-socket}
OMP_NUM_THREADS=${6:-1}
KMP_AFFINITY=${7:-compact1}
MPI_AFFINITY=${8:-numa}
THREADS_PER_SOCKET=${THREADS_PER_SOCKET:-}

#to solve one known limitation on Intel MPI: 
SHM_SIZE=8

# no need to set gated flag explictly. Just reserve the flag position for future
# If gated was set, will try to run minimal set of validation
TEST_GATED=""

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

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


# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.intel"
if [ $(echo ${CONFIG}| grep "avx") ]; then
    DOCKER_IMAGE="$DIR/Dockerfile.2.MKL"
fi
if [ "$CONFIG" = "amd-avx512" ] || [ "$CONFIG" = "amd-avx2" ]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.amd"
fi


ALL_KEYS="CONFIG TEST_GATED X_DIMENSION Y_DIMENSION Z_DIMENSION RUN_SECONDS OMP_NUM_THREADS PROCESS_PER_NODE KMP_AFFINITY MPI_AFFINITY THREADS_PER_SOCKET"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged --shm-size=${SHM_SIZE}gb $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"

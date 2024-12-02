#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ISA=${1:-avx2}
ARCH=${2:-intel}
MAP_BY=${3:-socket}
N_SIZE=${N_SIZE:-auto}
P_SIZE=${P_SIZE:-auto}
Q_SIZE=${Q_SIZE:-auto}
NB_SIZE=${NB_SIZE:-auto}
MPI_PROC_NUM=${MPI_PROC_NUM:-auto}
MPI_PER_NODE=${MPI_PER_NODE:-auto}
NUMA_PER_MPI=${NUMA_PER_MPI:-auto}
WORKLOAD="linpack_${ARCH}"
CASE_TYPE=$(echo ${ISA}|cut -d_ -f2)

# Overwrite parameters by --set
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
if [ $CASE_TYPE == "pdt" ]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.${ARCH}.pdt"
else
    DOCKER_IMAGE="$DIR/Dockerfile.1.${ARCH}"
fi

ALL_KEYS="N_SIZE P_SIZE Q_SIZE NB_SIZE ISA MAP_BY MPI_PROC_NUM MPI_PER_NODE NUMA_PER_MPI"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged --shm-size=8gb $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="-DSHM_SIZE=8gb ${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"

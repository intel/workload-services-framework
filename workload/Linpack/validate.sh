#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ASM=${1:-default_instruction}
ARCH=${2:-intel}
N_SIZE=${N_SIZE:-auto}
P_SIZE=${P_SIZE:-auto}
Q_SIZE=${Q_SIZE:-auto}
NB_SIZE=${NB_SIZE:-auto}
WORKLOAD="linpack_${ARCH}"

# Overwrite parameters by --set
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Check whether parameters are valid.
source "$DIR"/../../stack/ai_common/libs/parameter_precheck.sh
check_positive_integer_or_string "auto" $N_SIZE
check_positive_integer_or_string "auto" $P_SIZE
check_positive_integer_or_string "auto" $Q_SIZE 
check_positive_integer_or_string "auto" $NB_SIZE 

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
DOCKER_IMAGE="$DIR/Dockerfile.1.${ARCH}"

ALL_KEYS="N_SIZE P_SIZE Q_SIZE NB_SIZE ASM"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged --shm-size=16gb $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="-DSHM_SIZE=16gb ${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
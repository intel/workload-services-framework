#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORKLOAD=${WORKLOAD:-dlrmv2_pytorch_arm}
PLATFORM=${PLATFORM:-ARMv8}
PRECISION=${PRECISION:-FP32}
BATCH_SIZE=${BATCH_SIZE:-1}

TOPOLOGY=$(echo "${WORKLOAD}" | cut -d_ -f1)
MODE=$(echo "${CONTENT}" | cut -d_ -f2)
FUNCTION="inference"
DATA_TYPE=$(echo "${CONTENT}" | cut -d_ -f1)
PRECISION=$(echo "${OPTION}" | cut -d_ -f2)
LIB=$(echo "${OPTION}" | cut -d_ -f1)
ARCH=$(uname -m)

echo "The data type is ${DATA_TYPE}"
echo "The library is ${LIB}"

# Default values
BATCH_SIZE=${BATCH_SIZE:-1}
STEP=${STEP:-1}
NUM_INSTANCES=${NUM_INSTANCES:-1}
SWI=${SWI:-1}

# Accuracy mode settings
if [ "${MODE}" == "accuracy" ]; then
    BATCH_SIZE=16384
    STEP=5441
    SWI=0
    NUM_INSTANCES=1
fi

# Logs setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "${DIR}/../../script/overwrite.sh"

# Workload setting
WORKLOAD_PARAMS=(TOPOLOGY FUNCTION BATCH_SIZE NUM_INSTANCES MODE PRECISION ARCH STEP SWI LIB DATA_TYPE)

# Docker setting
DOCKER_IMAGE="dlrmv2-pytorch-arm-public"
if [ "${PRECISION}" == "fp32" ]; then
    DOCKER_OPTIONS="--privileged --net=host --ipc=host \
        -e TOPOLOGY=${TOPOLOGY} \
        -e FUNCTION=${FUNCTION} \
        -e BATCH_SIZE=${BATCH_SIZE} \
        -e NUM_INSTANCES=${NUM_INSTANCES} \
        -e MODE=${MODE} \
        -e PRECISION=${PRECISION} \
        -e ARCH=${ARCH} \
        -e STEP=${STEP} \
        -e SWI=${SWI} \
        -e LIB=${LIB} \
        -e DATA_TYPE=${DATA_TYPE}"
else
    DOCKER_OPTIONS="--privileged --net=host --ipc=host \
        -e ONEDNN_DEFAULT_FPMATH_MODE=BF16 \
        -e TOPOLOGY=${TOPOLOGY} \
        -e FUNCTION=${FUNCTION} \
        -e BATCH_SIZE=${BATCH_SIZE} \
        -e NUM_INSTANCES=${NUM_INSTANCES} \
        -e MODE=${MODE} \
        -e PRECISION=${PRECISION} \
        -e ARCH=${ARCH} \
        -e STEP=${STEP} \
        -e SWI=${SWI} \
        -e LIB=${LIB} \
        -e DATA_TYPE=${DATA_TYPE}"
fi

# Kubernetes setting
RECONFIG_OPTIONS="-DK_TOPOLOGY=${TOPOLOGY} \
    -DK_FUNCTION=${FUNCTION} \
    -DK_DOCKER_IMAGE=${DOCKER_IMAGE} \
    -DK_BATCH_SIZE=${BATCH_SIZE} \
    -DK_NUM_INSTANCES=${NUM_INSTANCES} \
    -DK_MODE=${MODE} \
    -DK_PRECISION=${PRECISION} \
    -DK_ARCH=${ARCH} \
    -DK_STEP=${STEP} \
    -DK_SWI=${SWI} \
    -DK_LIB=${LIB} \
    -DK_DATA_TYPE=${DATA_TYPE}"

JOB_FILTER="job-name=benchmark"

# Validate settings
. "${DIR}/../../script/validate.sh"

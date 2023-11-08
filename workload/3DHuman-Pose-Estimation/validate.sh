#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TESTCASE=${1:-latency_gated}

PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-3dhuman_pose_estimation}

# Default Workload Parameter
INFERENCE_FRAMEWORK="openvino"
INFERENCE_DEVICE="cpu"
INPUT_VIDEO="single_totalbody.mp4"

if [ ${#TAG} -eq 0 ]; then
  TAG=none
fi

if [ $(echo ${TESTCASE} | grep "pytorch") ]; then

  INFERENCE_FRAMEWORK="torch"

fi

if [ $(echo ${TESTCASE} | grep "gated") ]; then

  INPUT_VIDEO="video_short.mp4"

fi

# Logs Setting
DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(INFERENCE_FRAMEWORK INFERENCE_DEVICE INPUT_VIDEO)

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile"
DOCKER_OPTIONS="--privileged -e INFERENCE_FRAMEWORK=${INFERENCE_FRAMEWORK} -e INFERENCE_DEVICE=${INFERENCE_DEVICE} -e INPUT_VIDEO=${INPUT_VIDEO}"

# Kubernetes Setting
RECONFIG_OPTIONS="-DK_INFERENCE_FRAMEWORK=${INFERENCE_FRAMEWORK} -DK_INFERENCE_DEVICE=${INFERENCE_DEVICE} -DK_INPUT_VIDEO=${INPUT_VIDEO}"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"

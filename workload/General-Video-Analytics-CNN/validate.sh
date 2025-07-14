#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-general-video-analytics-cnn}
PLATFORM=${PLATFORM:-ARL}
TestTimeout=${TestTimeout:-120}
G_NumofVAStreams=${G_NumofVAStreams:-1}
G_Bind=${G_Bind:-true}
G_CPU_Bind=${G_CPU_Bind:-6-13}
TestName=${1:-arl-nn-i-dgpu-bs1}
SCALING_GOVERNOR=${SCALING_GOVERNOR:-powersave} # accepted values: powersave, performance

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

if [[ -e "$DIR/Dockerfile.2.arl.int" ]]; then
    INTERNAL=".int"
fi

# Workload Setting
WORKLOAD_PARAMS=(TESTCASE TestTimeout G_NumofVAStreams G_Bind G_CPU_Bind SCALING_GOVERNOR TestName)

# Docker Setting

DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Reconfig options
RECONFIG_OPTIONS="-DK_TESTCASE=$TESTCASE -DK_TestTimeout=$TestTimeout -DK_G_NumofVAStreams=$G_NumofVAStreams -DK_G_Bind=$G_Bind -DK_G_CPU_Bind=$G_CPU_Bind -DK_SCALING_GOVERNOR=$SCALING_GOVERNOR -DK_TestName=$TestName -DK_PLATFORM=$PLATFORM -DK_RELEASE=$RELEASE -DK_INTERNAL=$INTERNAL"
JOB_FILTER="job-name=general-video-analytics-cnn-benchmark"

. "$DIR/../../script/validate.sh"

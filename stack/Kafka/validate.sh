#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

DOCKER_IMAGE="$STACK-unittest"
echo $DOCKER_IMAGE

# Workload Setting
WORKLOAD_PARAMS=()

# Kubernetes Setting
RECONFIG_OPTIONS="-DDOCKER_IMAGE=${DOCKER_IMAGE}"
JOB_FILTER="job-name=kafka-version-check"

source "$DIR/../../script/validate.sh"
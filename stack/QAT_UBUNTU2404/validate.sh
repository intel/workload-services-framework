#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TCSUFFIX=$1

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(TCSUFFIX)

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.$TCSUFFIX"
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DTCSUFFIX=$TCSUFFIX -DSTACK=$STACK"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"


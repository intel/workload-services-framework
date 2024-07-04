#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Logs Setting
DIR=$(dirname $(readlink -f "$0"))
. "$DIR/../../script/overwrite.sh"

WORKLOAD_TEST=${WORKLOAD_TEST:="LIST DATABASES"}

# Workload Setting
WORKLOAD_PARAMS=(WORKLOAD_TEST)

# Docker Setting
DOCKER_IMAGE="$(ls -1 "$DIR"/Dockerfile.1.postgresql.base.unittest)"
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DCONFIG=$CONFIG"
JOB_FILTER="job-name=benchmark"

source "$DIR/../../script/validate.sh"
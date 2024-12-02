#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-WasmScore}
CONFIG=""

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=()

# Docker Setting
DOCKER_IMAGE=wasmscore
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DCONFIG=$CONFIG"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"


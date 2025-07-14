#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# General setting
OPTION=${1:-gated}
WORKLOAD=${WORKLOAD:-doris}

# Cluster Setting
if [[ "$OPTION" == "gated" ]]; then
    DORIS_BE_NUM=1
    DATA_SIZE_FACTOR=1
    DATA_GEN_THERADS=1
elif [[ "$OPTION" == "pkm" ]]; then
    DORIS_BE_NUM=1
    DATA_SIZE_FACTOR=10
    DATA_GEN_THERADS=20
else
    DORIS_BE_NUM=${DORIS_BE_NUM:-3}
    DATA_SIZE_FACTOR=${DATA_SIZE_FACTOR:-100}
    DATA_GEN_THERADS=${DATA_GEN_THERADS:-100}
fi
# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(DORIS_BE_NUM DATA_SIZE_FACTOR DATA_GEN_THERADS)

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DDORIS_BE_NUM=${DORIS_BE_NUM} -DDATA_SIZE_FACTOR=${DATA_SIZE_FACTOR} -DDATA_GEN_THERADS=${DATA_GEN_THERADS}"

# Used for log collection
JOB_FILTER="job-name=benchmark"

EVENT_TRACE_PARAMS="roi,begin region of interest,end region of interest"

. "$DIR/../../script/validate.sh"

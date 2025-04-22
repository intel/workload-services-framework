#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BENCHMARK_WL=${1:-"pts/nginx-3.0.1"}
PTS_NGINX301_DURATION=${PTS_NGINX301_DURATION:-90s}
PTS_NGINX301_CONNECTIONS=${PTS_NGINX301_CONNECTIONS:-400}

if [[ "$IMAGEARCH" != "linux/amd64" ]]; then
    IMARCH="-${IMAGEARCH/*\//}"
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(BENCHMARK_WL PTS_NGINX301_DURATION PTS_NGINX301_CONNECTIONS)

# Kubernetes Setting
RECONFIG_OPTIONS="-DBENCHMARK_WL=$BENCHMARK_WL -DPTS_NGINX301_DURATION=$PTS_NGINX301_DURATION -DPTS_NGINX301_CONNECTIONS=$PTS_NGINX301_CONNECTIONS"
JOB_FILTER="job-name=benchmark"

# Script Setting
SCRIPT_ARGS="$BENCHMARK_WL"

. "$DIR/../../script/validate.sh"

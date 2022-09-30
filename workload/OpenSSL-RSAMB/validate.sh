#!/bin/bash -e

CONFIG=${1:-qat-rsa}
WORKLOAD=${WORKLOAD:-openssl_rsamb_qatsw}
ASYNC_JOBS=${ASYNC_JOBS:-64}
PROCESSES=${PROCESSES:-8}
BIND_CORE=${BIND_CORE:-1c1t}
BIND=${BIND:-false}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS="mode:${CONFIG/-*/};algorithm:$(echo $CONFIG | cut -f2- -d-);ASYNC_JOBS:$ASYNC_JOBS;PROCESSES:$PROCESSES;BIND_CORE:$BIND_CORE;BIND:$BIND"

# Docker Setting

DOCKER_IMAGE="$DIR/Dockerfile.2.${WORKLOAD/*_/}"
DOCKER_OPTIONS="--privileged -e CONFIG=$CONFIG -e ASYNC_JOBS=$ASYNC_JOBS -e PROCESSES=$PROCESSES -e BIND_CORE=$BIND_CORE -e BIND=$BIND"

# Kubernetes Setting
RECONFIG_OPTIONS="-DCONFIG=$CONFIG -DASYNC_JOBS=$ASYNC_JOBS -DPROCESSES=$PROCESSES -DBIND_CORE=$BIND_CORE -DBIND=$BIND"
JOB_FILTER="job-name=benchmark"

# Script args
SCRIPT_ARGS="$TESTCASE"

. "$DIR/../../script/validate.sh"

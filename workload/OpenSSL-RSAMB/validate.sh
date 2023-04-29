#!/bin/bash -e

CONFIG=${1:-qat-rsa}
WORKLOAD=${WORKLOAD:-openssl_rsamb_qatsw}
PLATFORM=${PLATFORM:-SPR}
ASYNC_JOBS=${ASYNC_JOBS:-64}
PROCESSES=${PROCESSES:-8}
BIND_CORE=${BIND_CORE:-1c1t}
BIND=${BIND:-false}
MODE=${CONFIG/-*/}
ALGORITHM=$(echo $CONFIG | cut -f2- -d-)

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
if [[ "$CONFIG" = sw-* ]]; then
    WORKLOAD_PARAMS=(MODE ALGORITHM PROCESSES BIND_CORE BIND)
else
    WORKLOAD_PARAMS=(MODE ALGORITHM ASYNC_JOBS PROCESSES BIND_CORE BIND)
fi

# Docker Setting
if [[ "$CONFIG" = qathw* ]] && [ "$BACKEND" != "@pve" ]; then
    DOCKER_IMAGE=""
    DOCKER_OPTIONS=""
elif [[ "$CONFIG" = sw-* ]]; then
    DOCKER_IMAGE="$DIR/Dockerfile.2.${WORKLOAD/*_/}"
    DOCKER_OPTIONS="--privileged -e CONFIG=$CONFIG -e ASYNC_JOBS=$ASYNC_JOBS -e PROCESSES=$PROCESSES -e BIND_CORE=$BIND_CORE -e BIND=$BIND"
else
    DOCKER_IMAGE="$DIR/Dockerfile.2.${WORKLOAD/*_/}"
    DOCKER_OPTIONS="--privileged -v /dev/hugepages/qat:/dev/hugepages/qat -e CONFIG=$CONFIG -e ASYNC_JOBS=$ASYNC_JOBS -e PROCESSES=$PROCESSES -e BIND_CORE=$BIND_CORE -e BIND=$BIND"
fi

# Kubernetes Setting
RECONFIG_OPTIONS="-DCONFIG=$CONFIG -DASYNC_JOBS=$ASYNC_JOBS -DPROCESSES=$PROCESSES -DBIND_CORE=$BIND_CORE -DBIND=$BIND"
JOB_FILTER="job-name=benchmark"

# Script args
SCRIPT_ARGS="$TESTCASE"

. "$DIR/../../script/validate.sh"

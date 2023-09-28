#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-speccpu_2017_v119}
COMPILER=${1:-gcc12.1.0-lin}
PLATFORM1=${2:-icelake-server}
RELEASE1=${3:-20201206_20210202}
BENCHMARK=${4:-intrate}
TUNE=${5:-base}
COPIES=$6
RUNMODE=${7:-estimated}
NUMA=${8:-0}
PA_IP=$9
PA_PORT=${10}
VERSION=${WORKLOAD/*_/}
CASETYPE=$(echo "${TESTCASE}"|cut -d_ -f6)
ARGS=${ARGS:-}
ITERATION=${ITERATION:-1}
CPU_NODE=${CPU_NODE:-}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(BENCHMARK RUNMODE COPIES VERSION COMPILER TUNE PLATFORM1 NUMA RELEASE1 RELEASE2 PA_IP PA_PORT ARGS ITERATION CPU_NODE)

if [[ "$CASETYPE" == "pkm" ]]; then
    if [[ $BENCHMARK == "intrate" ]]; then
        EVENT_TRACE_PARAMS=${EVENT_TRACE_PARAMS:-"roi,Running 500,Running 502"}
    else
        EVENT_TRACE_PARAMS=${EVENT_TRACE_PARAMS:-"roi,Running 503,Running 507"}
    fi
fi

RELEASE2=${RELEASE1/*\%/}
RELEASE1=${RELEASE1/\%*/}

# Docker Setting
if [[ $WORKLOAD = *nda* ]]; then
    DOCKER_IMAGE="$(ls -1 "$DIR"/v119_external/Dockerfile.1.nda*-$RELEASE2*)"
else
    DOCKER_IMAGE="$(ls -1 "$DIR"/$VERSION/Dockerfile.1.*-$RELEASE2*)"
fi

DOCKER_OPTIONS="--privileged -e BENCHMARK=$BENCHMARK -e RUNMODE=$RUNMODE -e COPIES=$COPIES -e TUNE=$TUNE -e PLATFORM1=$PLATFORM1 -e COMPILER=$COMPILER -e NUMA=$NUMA -e RELEASE1=$RELEASE1 -e PA_IP=$PA_IP -e PA_PORT=$PA_PORT -e ARGS=$ARGS -e ITERATION=$ITERATION -e CPU_NODE=$CPU_NODE"

# Kubernetes Setting
RECONFIG_OPTIONS="-DDOCKER_IMAGE=$DOCKER_IMAGE -DBENCHMARK=$BENCHMARK -DRUNMODE=$RUNMODE -DCOPIES=$COPIES -DVERSION=$VERSION -DTUNE=$TUNE -DPLATFORM1=$PLATFORM1 -DCOMPILER=$COMPILER -DNUMA=$NUMA -DRELEASE1=$RELEASE1 -DRELEASE2=$RELEASE2 -DPA_IP=$PA_IP -DPA_PORT=$PA_PORT -DARGS=$ARGS -DITERATION=$ITERATION -DCPU_NODE=$CPU_NODE"
JOB_FILTER="job-name=speccpu-2017-benchmark"

. "$DIR/../../script/validate.sh"

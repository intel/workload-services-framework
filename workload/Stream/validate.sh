#!/bin/bash -e

WORKLOAD=${WORKLOAD:-stream}
INSTRUCTION_SET=${1:-sse}
NTIMES=${NTIMES:-100}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(INSTRUCTION_SET NTIMES)

# Docker Setting
DOCKER_IMAGE="$DIR/intel/Dockerfile.1.intel"

DOCKER_OPTIONS="-e INSTRUCTION_SET=${INSTRUCTION_SET} -e NTIMES=${NTIMES} -e WORKLOAD=$WORKLOAD -e PLATFORM=$PLATFORM"

# Kubernetes Setting
RECONFIG_OPTIONS="-DDOCKER_IMAGE=${DOCKER_IMAGE} -DINSTRUCTION_SET=${INSTRUCTION_SET} -DNTIMES=${NTIMES} -DWORKLOAD=${WORKLOAD} -DPLATFORM=$PLATFORM"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"

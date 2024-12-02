#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


# define the workload arguments
TEST_CASES=${1:-allinone}
ITERATION_COUNT=${ITERATION_COUNT:-10}
PARALLEL_COUNT=${PARALLEL_COUNT:-1}
NUMACTL_OPTIONS=${NUMACTL_OPTIONS:-""}
NUMA_ENABLE=${NUMA_ENABLE:-false}

# Logs Setting
  # DIR is the workload script directory. When validate.sh is executed, the current
  # directory is usually the logs directory.
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(ITERATION_COUNT PARALLEL_COUNT NUMACTL_OPTIONS TEST_CASES NUMA_ENABLE)
# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile"
DOCKER_OPTIONS="-e ITERATION_COUNT=${ITERATION_COUNT} -e PARALLEL_COUNT=${PARALLEL_COUNT} -e TEST_CASES=${TEST_CASES} -e NUMA_ENABLE=${NUMA_ENABLE}"
# Kubernetes Setting
RECONFIG_OPTIONS="-DITERATION_COUNT=${ITERATION_COUNT} -DPARALLEL_COUNT=${PARALLEL_COUNT} -DNUMACTL_OPTIONS=${NUMACTL_OPTIONS} -DTEST_CASES=${TEST_CASES} -DNUMA_ENABLE=${NUMA_ENABLE}"

JOB_FILTER="job-name=benchmark"

# kpi args
# SCRIPT_ARGS="${SCALE}"
EVENT_TRACE_PARAMS="roi,Start Test,Test Done"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"


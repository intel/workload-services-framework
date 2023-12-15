#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function concat_params() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="$i"
        else
            RET="${RET} $i"
        fi
    done
    echo "$RET"
}

function k8s_settings() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="-D$i=\$$i"
        else
            RET="${RET} -D$i=\$$i"
        fi
    done
    echo "$RET"
}

# define the workload arguments
# Workload settings
WORKLOAD=${WORKLOAD:-tpcds-spark}
SCALE_FACTOR=${1:-gated}
NUM_WORKERS=${NUM_WORKERS:-3}
MOUNT_DISK=${MOUNT_DISK:-true}
DFS_DIR_DISK_NUM=${DFS_DIR_DISK_NUM:-1}
YARN_LOCAL_DIR_DISK_NUM=${YARN_LOCAL_DIR_DISK_NUM:-0}
SPARK_LOCAL_DIR_DISK_NUM=${SPARK_LOCAL_DIR_DISK_NUM:-0}
GATED=false
NUM_NODES=4


WORKLOAD_KEYS="WORKLOAD SCALE_FACTOR NUM_WORKERS NUM_NODES MOUNT_DISK GATED DFS_DIR_DISK_NUM YARN_LOCAL_DIR_DISK_NUM SPARK_LOCAL_DIR_DISK_NUM"

# Spark settings
# spark.executor.cores
SPARK_EXECUTOR_CORES=${SPARK_EXECUTOR_CORES:-6}
# spark.memory.fraction
SPARK_MEMORY_FRACTION=${SPARK_MEMORY_FRACTION:-0.6}
# spark.memory.storageFraction
SPARK_MEMORY_STORAGE_FRACTION=${SPARK_MEMORY_STORAGE_FRACTION:-0.5}
# spark.executor.memoryOverhead
SPARK_EXECUTOR_MEMORY_OVERHEAD=${SPARK_EXECUTOR_MEMORY_OVERHEAD:-1}
# Factor used to calculate:
# spark.default.parallelism = CPU_CORES*SPARK_PARALLELISM_FACTOR
# spark.sql.shuffle.partitions = CPU_CORES*SPARK_PARALLELISM_FACTOR
SPARK_PARALLELISM_FACTOR=${SPARK_PARALLELISM_FACTOR:-2}

# by default Yarn will use only 80% of memory, and leave 20% for operating system (tweak this for different Scalefactor)
SPARK_AVAILABLE_MEMORY=${SPARK_AVAILABLE_MEMORY:-0.8}

SPARK_KEYS="SPARK_EXECUTOR_CORES SPARK_MEMORY_FRACTION SPARK_MEMORY_STORAGE_FRACTION SPARK_PARALLELISM_FACTOR SPARK_AVAILABLE_MEMORY SPARK_EXECUTOR_MEMORY_OVERHEAD"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

NUM_NODES=$((NUM_WORKERS+1))
if [[ $SCALE_FACTOR == "gated" ]]; then
    SCALE_FACTOR=1
    MOUNT_DISK=false
    GATED=true
    NUM_WORKERS=1
    NUM_NODES=1
    SPARK_EXECUTOR_CORES=4
elif [[ $SCALE_FACTOR == "pkm" ]]; then
    SCALE_FACTOR=100
fi

ALL_KEYS="$(concat_params $WORKLOAD_KEYS $SPARK_KEYS)"

WORKLOAD_PARAMS=($ALL_KEYS)

# EVENT_TRACE_PARAMS for collecting emon data
EVENT_TRACE_PARAMS="roi,Running execution q1-v2.4,Running execution q99-v2.4"

# Docker Setting
  # if the workload does not support docker run, leave DOCKER_IMAGE empty.
  # Otherwise, specify the image name and the docker run options.
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="$(eval echo "$(k8s_settings $ALL_KEYS)")"
JOB_FILTER="job-name=master-0"


. "$DIR/../../script/validate.sh"

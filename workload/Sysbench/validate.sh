#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details.

# define the workload arguments
TEST_TYPE=${1:-gated}
THREADS=${THREADS:-1}
TIME=${TIME:-120}

# Logs Setting
  # DIR is the workload script directory. When validate.sh is executed, the current
  # directory is usually the logs directory.
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, given a
  # TEST_CONFIG yaml configuration. See doc/user-guide/executing-workload/ctest.md for details.
. "$DIR/../../script/overwrite.sh"

if [[ "${TESTCASE}" =~ ^test.*cpu_pkm$ ]]; then
    TEST_TYPE="cpu"
fi
if [[ "${TESTCASE}" =~ ^test.*mutex_pkm$ ]]; then
    TEST_TYPE="mutex"
fi
if [[ "${TESTCASE}" =~ ^test.*memory_pkm$ ]]; then
    TEST_TYPE="memory"
fi
if [[ "${TESTCASE}" =~ ^test.*mysql_pkm$ ]]; then
    TEST_TYPE="mysql"
fi

#For ARCH keyword


if [[ "$TEST_TYPE" == "gated" ]]; then
    MODE=${MODE:-cpu}
    CPU_MAX_PRIME=${CPU_MAX_PRIME:-5000}
    # Workload Setting
    WORKLOAD_PARAMS=(MODE THREADS TIME CPU_MAX_PRIME)
    # Docker Setting
    DOCKER_IMAGE="$DIR/Dockerfile"
    DOCKER_OPTIONS="-e MODE=$MODE -e THREADS=$THREADS -e TIME=$TIME -e CPU_MAX_PRIME=$CPU_MAX_PRIME"
    # Kubernetes Setting
    RECONFIG_OPTIONS="-DMODE=$MODE -DTHREADS=$THREADS -DTIME=$TIME -DCPU_MAX_PRIME=$CPU_MAX_PRIME"
elif [[ "$TEST_TYPE" == "cpu" ]]; then
    echo "Testing cpu performance."
    CPU_MAX_PRIME=${CPU_MAX_PRIME:-20000}
    # Workload Setting
    WORKLOAD_PARAMS=(TEST_TYPE THREADS TIME CPU_MAX_PRIME)
    # Docker Setting
    DOCKER_IMAGE="$DIR/Dockerfile"
    DOCKER_OPTIONS="-e MODE=$TEST_TYPE -e THREADS=$THREADS -e TIME=$TIME -e CPU_MAX_PRIME=$CPU_MAX_PRIME"
    # Kubernetes Setting
    RECONFIG_OPTIONS="-DMODE=$TEST_TYPE -DTHREADS=$THREADS -DTIME=$TIME -DCPU_MAX_PRIME=$CPU_MAX_PRIME"
elif [[ "$TEST_TYPE" == "mutex" ]]; then
    echo "Testing mutex performance."
    MUTEX_LOCKS=${MUTEX_LOCKS:-1}
    # Workload Setting
    WORKLOAD_PARAMS=(TEST_TYPE THREADS MUTEX_LOCKS)
    # Docker Setting
    DOCKER_IMAGE="$DIR/Dockerfile"
    DOCKER_OPTIONS="-e MODE=$TEST_TYPE -e THREADS=$THREADS -e MUTEX_LOCKS=$MUTEX_LOCKS"
    # Kubernetes Setting
    RECONFIG_OPTIONS="-DMODE=$TEST_TYPE -DTHREADS=$THREADS -DMUTEX_LOCKS=$MUTEX_LOCKS"
elif [[ "$TEST_TYPE" == "memory" ]]; then
    echo "Testing memory performance."
    MEMORY_BLOCK_SIZE=${MEMORY_BLOCK_SIZE:-4k}
    MEMORY_TOTAL_SIZE=${MEMORY_TOTAL_SIZE:-10G}
    MEMORY_SCOPE=${MEMORY_SCOPE:-global}
    MEMORY_OPER=${MEMORY_OPER:-read}
    MEMORY_ACCESS_MODE=${MEMORY_ACCESS_MODE:-seq}

    # Workload Setting
    WORKLOAD_PARAMS=(TEST_TYPE THREADS TIME MEMORY_BLOCK_SIZE MEMORY_TOTAL_SIZE MEMORY_SCOPE MEMORY_OPER MEMORY_ACCESS_MODE)
    # Docker Setting
    DOCKER_IMAGE="$DIR/Dockerfile"
    DOCKER_OPTIONS="-e MODE=$TEST_TYPE -e THREADS=$THREADS -e TIME=$TIME -e MEMORY_BLOCK_SIZE=$MEMORY_BLOCK_SIZE -e MEMORY_TOTAL_SIZE=$MEMORY_TOTAL_SIZE -e MEMORY_SCOPE=$MEMORY_SCOPE -e MEMORY_OPER=$MEMORY_OPER -e MEMORY_ACCESS_MODE=$MEMORY_ACCESS_MODE"
    # Kubernetes Setting
    RECONFIG_OPTIONS="-DMODE=$TEST_TYPE -DTHREADS=$THREADS -DTIME=$TIME -DMEMORY_BLOCK_SIZE=$MEMORY_BLOCK_SIZE -DMEMORY_TOTAL_SIZE=$MEMORY_TOTAL_SIZE -DMEMORY_SCOPE=$MEMORY_SCOPE -DMEMORY_OPER=$MEMORY_OPER -DMEMORY_ACCESS_MODE=$MEMORY_ACCESS_MODE"
elif [[ "$TEST_TYPE" == "mysql" ]]; then
    echo "Testing mysql performance."
    MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-Mysql@123}
    TABLES_NUM=${TABLES_NUM:-16}
    TABLE_SIZE=${TABLE_SIZE:-10000}
    BUFFER_POOL_SIZE=${BUFFER_POOL_SIZE:-4}
    if ! [ $MYSQL_INNODB_BUFFER_POOL_SIZE ]; then
    MYSQL_INNODB_BUFFER_POOL_SIZE=$BUFFER_POOL_SIZE;
    [ $MYSQL_INNODB_BUFFER_POOL_SIZE -gt 64 ] && MYSQL_INNODB_BUFFER_POOL_SIZE=64;
        MYSQL_INNODB_BUFFER_POOL_SIZE="${MYSQL_INNODB_BUFFER_POOL_SIZE}G"
    fi

    # Workload Setting
    WORKLOAD_PARAMS=(TEST_TYPE THREADS TIME MYSQL_ROOT_PASSWORD TABLES_NUM TABLE_SIZE MYSQL_INNODB_BUFFER_POOL_SIZE)

    # Docker Setting
    DOCKER_IMAGE="$DIR/Dockerfile"
    DOCKER_OPTIONS="--privileged -e MYSQL_INNODB_BUFFER_POOL_SIZE=$MYSQL_INNODB_BUFFER_POOL_SIZE -e MODE=$TEST_TYPE -e THREADS=$THREADS -e TIME=$TIME -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} -e TABLES_NUM=${TABLES_NUM} -e TABLE_SIZE=${TABLE_SIZE}"

    # Kubernetes Setting
    RECONFIG_OPTIONS="-DMODE=$TEST_TYPE -DTHREADS=$THREADS -DTIME=$TIME -DMYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}  -DTABLES_NUM=${TABLES_NUM} -DTABLE_SIZE=${TABLE_SIZE}"
fi

DOCKER_IMAGE="$DIR/Dockerfile.1.sysbench"
RECONFIG_OPTIONS="${RECONFIG_OPTIONS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

#Event tracing parameters
if [[ "${TESTCASE}" =~ ^test.*_pkm$ ]]; then
    EVENT_TRACE_PARAMS="roi,Begin performance testing,End performance testing"
fi

JOB_FILTER="job-name=benchmark"

# kpi args
# SCRIPT_ARGS="${SCALE}"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"


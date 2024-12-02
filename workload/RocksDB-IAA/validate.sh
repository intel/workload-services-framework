#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
COMPRESSED=${1:-zstd}
TYPE=${2:-readrandom}
KEY_SIZE=${KEY_SIZE:-16}
VALUE_SIZE=${VALUE_SIZE:-32}
BLOCK_SIZE=${BLOCK_SIZE:-16} # 16k
DB_CPU_LIMIT=${DB_CPU_LIMIT:-8}
NUM_SOCKETS=${NUM_SOCKETS:-1}
NUM_DISKS=${NUM_DISKS:-1}


# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

WORKLOAD_PARAMS=(COMPRESSED TYPE KEY_SIZE VALUE_SIZE BLOCK_SIZE DB_CPU_LIMIT NUM_SOCKETS NUM_DISKS)

EVENT_TRACE_PARAMS="roi,begin region of interest,end region of interest"

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""
# Kubernetes Setting
RECONFIG_OPTIONS="-DCOMPRESSED=${COMPRESSED} -DTYPE=$TYPE -DKEY_SIZE=$KEY_SIZE -DVALUE_SIZE=$VALUE_SIZE -DBLOCK_SIZE=$BLOCK_SIZE -DDB_CPU_LIMIT=$DB_CPU_LIMIT -DNUM_SOCKETS=$NUM_SOCKETS -DNUM_DISKS=$NUM_DISKS"
JOB_FILTER="job-name=rocksdb-iaa"

# kpi args
SCRIPT_ARGS=$(echo ${TYPE} | cut -d"_" -f2)

. "$DIR/../../script/validate.sh"
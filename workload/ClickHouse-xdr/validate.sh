#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-clickhouse_xdr_internal_hyperscan}
TESTCASE=${TESTCASE:-clickhouse_xdr_internal_hyperscan_baseline}

# Client settings
CLIENT_CORE_LIST=${CLIENT_CORE_LIST:-"0-0"}

# Server settings
SERVER_CORE_LIST=${SERVER_CORE_LIST:-"1-1"}
SERVER_MAX_THREADS=${SERVER_MAX_THREADS:-"1"}

IMAGE_TYPE=""
[[ $TESTCASE == *_internal_hyperscan_* ]] && IMAGE_TYPE="internal-hyperscan"
[[ $TESTCASE == *_internal_hyperscan_avx512 ]] && IMAGE_TYPE="internal-hyperscan-avx512"
[[ $TESTCASE == *_public_hyperscan_* ]] && IMAGE_TYPE="public-hyperscan"
[[ $TESTCASE == *_public_hyperscan_avx512 ]] && IMAGE_TYPE="public-hyperscan-avx512"
[[ $TESTCASE == *_vectorscan_* ]] && IMAGE_TYPE="vectorscan"

if [[ "$TESTCASE" =~ "_gated"$ ]]; then
  CLIENT_CORE_LIST="0-0"
  SERVER_CORE_LIST="1-1"
  SERVER_MAX_THREADS=1
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(WORKLOAD IMAGE_TYPE SERVER_CORE_LIST CLIENT_CORE_LIST SERVER_MAX_THREADS)

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="\
-DWORKLOAD=$WORKLOAD \
-DIMAGE_TYPE=$IMAGE_TYPE \
-DSERVER_CORE_LIST=$SERVER_CORE_LIST \
-DCLIENT_CORE_LIST=$CLIENT_CORE_LIST \
-DSERVER_MAX_THREADS=$SERVER_MAX_THREADS"

JOB_FILTER="job-name=clickhouse-xdr"

# Script Setting
# SCRIPT_ARGS="$CLIENT_TYPE"

. "$DIR/../../script/validate.sh"

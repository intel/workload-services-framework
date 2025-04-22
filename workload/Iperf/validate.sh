#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-iperf}

# general parameters
IPERF_VER=${1:-2}
PROTOCOL=${2:-TCP}
MODE=${3:-pod2pod}

# server parameters
SERVER_POD_PORT=${SERVER_POD_PORT:-35201}
SERVER_PING_PORT=${SERVER_PING_PORT:-32399}
SERVER_CORE_COUNT=${SERVER_CORE_COUNT:-1}
SERVER_CORE_LIST=${SERVER_CORE_LIST:-"-1"}
SERVER_OPTIONS=${SERVER_OPTIONS:-""}

# server service parameters
case "$MODE" in
pod2svc|ingress)
    IPERF_SERVICE_NAME=${IPERF_SERVICE_NAME:-iperf-server-service}
    if [ "$BACKEND" = "terraform" ] && [[ "$TERRAFORM_OPTIONS$CTESTSH_OPTIONS" != *"--kubernetes"* ]] && [[ "$TERRAFORM_OPTIONS$CTESTSH_OPTIONS" = *"--docker"* ]]; then
        echo "$MODE not supported by docker"
        exit 3
    elif [ "$BACKEND" = "kubernetes" ] && [ "$MODE" = "ingress" ]; then
        echo "$MODE not supported by kubernetes"
        exit 3
    elif [ "$BACKEND" = "docker" ]; then
        echo "$MODE not supported by docker"
        exit 3
    fi
    ;;
pod2pod)
    IPERF_SERVICE_NAME=${IPERF_SERVICE_NAME:-iperf-server}
    ;;
esac

# client parameters
CLIENT_CORE_COUNT=${CLIENT_CORE_COUNT:-1}
CLIENT_CORE_LIST=${CLIENT_CORE_LIST:-"-1"}
PARALLEL_NUM=${PARALLEL_NUM:-8}
CLIENT_TRANSMIT_TIME=${CLIENT_TRANSMIT_TIME:-30}
if [[ $PROTOCOL == TCP ]]; then
  BUFFER_SIZE=${BUFFER_SIZE:-128K}
else
  BUFFER_SIZE=${BUFFER_SIZE:-1470}
fi
UDP_BANDWIDTH=${UDP_BANDWIDTH:-50M}
CLIENT_OPTIONS=${CLIENT_OPTIONS:-""}
ONLY_USE_PHY_CORE=${ONLY_USE_PHY_CORE:-yes}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(IPERF_VER MODE SERVER_POD_PORT SERVER_PING_PORT SERVER_CORE_COUNT SERVER_CORE_LIST SERVER_OPTIONS IPERF_SERVICE_NAME PROTOCOL CLIENT_CORE_COUNT CLIENT_CORE_LIST PARALLEL_NUM CLIENT_TRANSMIT_TIME BUFFER_SIZE UDP_BANDWIDTH CLIENT_OPTIONS ONLY_USE_PHY_CORE)

# Kubernetes Setting
JOB_FILTER="job-name=iperf-server"

. "$DIR/../../script/validate.sh"

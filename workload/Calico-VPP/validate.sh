#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-"Calico-VPP"}

ENABLE_DSA=${1:-"false"}

# define the workload arguments per hugepage size 2048(2Mi)/1048576(1Gi)
PER_HUGEPAGE_SIZE=${PER_HUGEPAGE_SIZE:-1048576}
MTU=${MTU:-1500}
CORE_SIZE=${CORE_SIZE:-1}

### VPP ###
VPP_CORE_START=${VPP_CORE_START:-10}

### Trex ###
TREX_CPU_REQUESTS=${TREX_CPU_REQUESTS:-8}
TREX_HUGEPAGES=${TREX_HUGEPAGES:-8}
HUGEPAGES=${HUGEPAGES:-16}
MASTER_THREAD_ID=${MASTER_THREAD_ID:-20}
LATENCY_THREAD_ID=${LATENCY_THREAD_ID:-21}
TREX_THREADS=${TREX_THREADS:-"22.23.24.25.26.27.28.29"}

TREX_PACKET_SIZE=${TREX_PACKET_SIZE:-1024}
TREX_DURATION=${TREX_DURATION:-30} 
TREX_SOURCE_IP=${TREX_SOURCE_IP:-"10.10.10.10"} 
TREX_STREAM_NUM=${TREX_STREAM_NUM:-1} 
TREX_CORE_NUM=${TREX_CORE_NUM:-8}

### L3 Forward ###
L3FWD_CORE_START=${L3FWD_CORE_START:-20}

images=(calicovpp_dsa_agent calicovpp_dsa_vpp calicovpp_l3fwd calicovpp_trex)
if [ -n "$REGISTRY" ]; then  
  for i in ${images[@]}
    do
      docker pull $REGISTRY${i}$RELEASE
      docker image tag $REGISTRY${i}$RELEASE ${i}${RELEASE}
    done
fi 

# Logs Setting
  # DIR is the workload script directory. When validate.sh is executed, 
  # the current directory is usually the logs directory. 
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(
    PER_HUGEPAGE_SIZE MTU CORE_SIZE ENABLE_DSA VPP_CORE_START TREX_CPU_REQUESTS TREX_HUGEPAGES HUGEPAGES TREX_PACKET_SIZE TREX_DURATION 
    TREX_SOURCE_IP TREX_STREAM_NUM TREX_CORE_NUM L3FWD_CORE_START MASTER_THREAD_ID LATENCY_THREAD_ID TREX_THREADS
)

# Kubernetes Setting
RECONFIG_OPTIONS="-DPER_HUGEPAGE_SIZE=${PER_HUGEPAGE_SIZE} -DMTU=${MTU} -DCORE_SIZE=${CORE_SIZE} -DENABLE_DSA=${ENABLE_DSA} -DVPP_CORE_START=${VPP_CORE_START}  \
                  -DTREX_HUGEPAGES=${TREX_HUGEPAGES} -DTREX_CPU_REQUESTS=${TREX_CPU_REQUESTS} -DTREX_PACKET_SIZE=${TREX_PACKET_SIZE} -DTREX_STREAM_NUM=${TREX_STREAM_NUM} \
                  -DTREX_CORE_NUM=${TREX_CORE_NUM} -DTREX_DURATION=${TREX_DURATION} -DTREX_SOURCE_IP=${TREX_SOURCE_IP} -DL3FWD_CORE_START=${L3FWD_CORE_START}\
                  -DHUGEPAGES=${HUGEPAGES} -DMASTER_THREAD_ID=${MASTER_THREAD_ID} -DLATENCY_THREAD_ID=${LATENCY_THREAD_ID} -DTREX_THREADS=${TREX_THREADS}"

JOB_FILTER="job-name=benchmark"

# kpi args
SCRIPT_ARGS=""

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"

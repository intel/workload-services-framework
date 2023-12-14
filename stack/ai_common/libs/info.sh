#! /bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Workload params
TOPOLOGY=$TOPOLOGY
MODE=$MODE
PRECISION=$PRECISION
FUNCTION=$FUNCTION
DATA_TYPE=$DATA_TYPE
BATCH_SIZE=$BATCH_SIZE
STEPS=$STEPS
CORES_PER_INSTANCE=$CORES_PER_INSTANCE
INSTANCE_NUMBER=$INSTANCE_NUMBER
SHARE_WEIGHT_INSTANCE=$SHARE_WEIGHT_INSTANCE
WEIGHT_SHARING=$WEIGHT_SHARING
DNNL_PRIMITIVE_CACHE_CAPACITY_topology="maskrcnn-resnet50_v15-resnext101_32x16d-rnn_t-ssd_rn34"

# CPU info
SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
NUMA_NODES=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
THREADS_PER_CORE=`lscpu | grep "Thread(s) per core" | awk -F ':' '{print $2}'`
TOTAL_CORES=$(expr ${CORES_PER_SOCKET} \* ${SOCKETS})
CORES_PER_NUMA=$(expr ${TOTAL_CORES} \/ ${NUMA_NODES})

if [ -z "$CORES_PER_INSTANCE" ] || [ "$CORES_PER_INSTANCE" == "0" ]; then
    CORES_PER_INSTANCE=${CORES_PER_NUMA}
fi

INSTANCE_NUMA=$(expr ${NUMA_NODES} \* ${CORES_PER_INSTANCE})

if [ "$TOPOLOGY" == "resnet50v1_5" ]; then
    WARMUP_STEPS=$(expr $STEPS \/ 4)
fi

if [ -z "$TOPOLOGY" ]; then
    echo "Not find topology ${TOPOLOGY}"
    exit 1
fi
if [ -z "$MODE" ]; then
    echo "Not find mode ${MODE}"
    exit 1
fi
if [ -z "$PRECISION" ]; then
    echo "Not find precision ${PRECISION}"
    exit 1
fi
if [ -z "$FUNCTION" ]; then
    echo "Not find function ${FUNCTION}"
    exit 1
fi

if [ -z "$WEIGHT_SHARING" ]; then
    WEIGHT_SHARING=False
fi

if [ "$WEIGHT_SHARING" == "True" ]; then
    INTER_THREADS=-1
else
    INTER_THREADS=1
fi

if [ "$WEIGHT_SHARING" == "False" ]; then
    INTRA_THREADS=${CORES_PER_INSTANCE}
else
    INTRA_THREADS=${CORES_PER_NUMA}
fi

# Set SNCen
if [ $NUMA_NODES -ne $SOCKETS ]; then
    SNCen=True
else
    SNCen=False
fi

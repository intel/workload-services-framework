#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

CORES_PER_SOCKET=$(lscpu | grep "Core(s) per socket:" | awk '{print $4}')
NUM_SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $2}')
TOTAL_CORES=$(expr ${CORES_PER_SOCKET} \* ${NUM_SOCKETS})

BATCH_SIZE=$BATCH_SIZE
NUM_INSTANCES=$NUM_INSTANCES
STEP=$STEP
SWI=$SWI

echo "The parameters:"
echo "Topology: $TOPOLOGY"
echo "Mode: $MODE"
echo "Function: $FUNCTION"
echo "Data Type: $DATA_TYPE"
echo "Precision: $PRECISION"
echo "Batch Size: $BATCH_SIZE"
echo "Steps: $STEP"

RUN_CMD="python dlrm_s_pytorch.py --mini-batch-size=${BATCH_SIZE} \
                                    --num-batches=${STEP} \
                                    --data-generation=random \
                                    --arch-mlp-bot=512-512-64 \
                                    --arch-mlp-top=1024-1024-1024-1 \
                                    --arch-sparse-feature-size=64 \
                                    --arch-embedding-size=1000000-1000000-1000000-1000000-1000000-1000000-1000000-1000000 \
                                    --num-indices-per-lookup=100 \
                                    --arch-interaction-op=dot \
                                    --numpy-rand-seed=727 \
                                    --memory-map \
                                    --mlperf-logging \
                                    --share-weight-instance=${SWI} \
                                    --print-freq=10 --print-time --inference-only"
#fi

echo "Run DLRMv2 inference benchmark"
echo "The command lines:"
set -x # echo the next command

if [ "${NUM_INSTANCES}" = "1" ]; then
    OMP_NUM_THREADS=$TOTAL_CORES
    EXPORT_CMD="export OMP_NUM_THREADS=${OMP_NUM_THREADS}"
    $EXPORT_CMD && numactl --physcpubind=0-$(expr ${OMP_NUM_THREADS} - 1) -m 0 $RUN_CMD
else
    OMP_NUM_THREADS=$(expr ${TOTAL_CORES} / ${NUM_INSTANCES})
    EXPORT_CMD="export OMP_NUM_THREADS=${OMP_NUM_THREADS}"
    start_core=0
    end_core=$(expr ${OMP_NUM_THREADS} - 1)

    i=0
    while [ $i -lt ${NUM_INSTANCES} ]
    do
        $EXPORT_CMD && numactl --physcpubind=${start_core}-${end_core} -m 0 $RUN_CMD &
        start_core=$(expr ${start_core} + ${OMP_NUM_THREADS})
        end_core=$(expr ${end_core} + ${OMP_NUM_THREADS})
        i=$(expr $i + 1)
    done
fi

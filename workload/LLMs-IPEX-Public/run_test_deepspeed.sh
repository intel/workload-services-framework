#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

source activate llm

SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
# NUMA_NODES=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'| tr -d "[:space:]"`
NUMA_NODES=`lscpu | grep  "NUMA node.*CPU(s).*[0-9]$" | wc -l`
CORES_PER_NUMA=$(( $SOCKETS * $CORES_PER_SOCKET / $NUMA_NODES ))
echo "CORES_PER_INSTANCE: ${CORES_PER_NUMA}"

# not support 
if [[ "${PRECISION}" != "woq_int8" ]] && [[ "${PRECISION}" != "bfloat16" ]]; then
    echo "Run error, This precision is ${PRECISION} not supported for DeepSpeed, please choose bfloat16 or woq_int8"
    exit 1
fi

if [[ "${MODEL_NAME}" == *"chatglm"* ]]; then
    echo "Run error, ${MODEL_NAME} do not support DeepSpeed"
    exit 1
elif [[ "${MODEL_NAME}" == *"Llama"* ]] && [[ "${MODE}" == "accuracy" ]]; then
    echo "Run error, ${MODEL_NAME} do not support accuracy+DeepSpeed"
    exit 1
fi

# base args
if [ "${MODE}" == "accuracy" ]; then
    EXEC_ARGS=" --model ${MODEL_NAME} --tasks 'lambada_openai' --batch-size ${BATCH_SIZE}"
else
    EXEC_ARGS=" --benchmark \
                --input-tokens=${INPUT_TOKENS} \
                --max-new-tokens ${OUTPUT_TOKENS} \
                --num-iter=${STEPS} \
                --num-warmup=${WARMUP_STEPS} \
                --batch-size=${BATCH_SIZE} \
                -m ${MODEL_NAME}"
    if [ "$OUTPUT_TOKENS" != "1" ]; then
        EXEC_ARGS+=" --token-latency"
    fi
fi

if [[ "${MODEL_NAME}" == *"mpt"* ]]; then
    MODEL_NAME=$(echo ${MODEL_NAME}|cut -d "/" -f2| cut -d "-" -f1-2)
    EXEC_ARGS+=" --config-file=./utils/model_config/mosaicml_${MODEL_NAME}_config.json"
fi
# greedy or beam search
if [ "$GREEDY" == "True" ]; then
    EXEC_ARGS+=" --greedy"
    echo "BEAM: 1"
else
    echo "BEAM: 4" 
fi

# script name
if [ "${MODE}" == "accuracy" ]; then
    unset KMP_AFFINITY
    echo "DS_TP: ${NUMA_NODES}"
    EVAL_ARGS="deepspeed  --num_gpus 2 --master_addr `hostname -I | sed -e 's/\s.*$//'` --bind_cores_to_rank"
    EVAL_SCRIPT="distributed/run_accuracy_with_deepspeed.py"
      
else
    TOTAL_CORES=$((SOCKETS*CORES_PER_SOCKET))
    CORES_PER_NUMA=$((TOTAL_CORES/NUMA_NODES))
    RANKS_PER_SOCKET=$((CORES_PER_SOCKET/CORES_PER_NUMA))
    if [ "${RANK_USE}" == "0" ] || [ "${RANK_USE}" == "1" ]; then
        echo "DS_TP: ${RANKS_PER_SOCKET}"
        BIND_CORE_LIST=$((RANK_USE*CORES_PER_SOCKET))-$(((RANK_USE+1)*CORES_PER_SOCKET-1))
        EVAL_ARGS="deepspeed --num_accelerators ${RANKS_PER_SOCKET} --bind_cores_to_rank --bind_core_list ${BIND_CORE_LIST}"
    else
        echo "DS_TP: ${NUMA_NODES}"
        EVAL_ARGS="deepspeed --bind_cores_to_rank"
    fi
    EVAL_SCRIPT="run.py"
fi

# execute parameters
if [ "${PRECISION}" == "bfloat16" ]; then
    EXEC_ARGS+=" --dtype bfloat16 --ipex"
    if [ "${MODE}" != "accuracy" ]; then
        EXEC_ARGS+=" --autotp --shard-model"
    fi
elif [ "${PRECISION}" == "woq_int8" ]; then
    EXEC_ARGS+=" --ipex-weight-only-quantization --weight-dtype INT8 --quant-with-amp"
    if [ "${MODE}" != "accuracy" ]; then
        EXEC_ARGS+=" --autotp --shard-model --output-dir saved_results"
    fi
fi
echo "Start case topology"
echo "Run cmd: ${EVAL_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}"
eval ${EVAL_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}
echo "Finish case topology"

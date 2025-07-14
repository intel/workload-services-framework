#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# quantization for precision woq_int4(local quantization script) static_int8
quantization_model(){
    if ([[ "${PRECISION}" == "woq_int4" ]] && [[ "${MODEL_NAME}" == *"gpt"* ]]) || [[ "${PRECISION}" == "static_int8" ]]; then
        OUTPUT_DIR="${TRANSFORMERS_CACHE}/public/saved_results_${PRECISION}"
        if [ ! -f "${OUTPUT_DIR}/best_model.pt" ]; then
            rm -rf ${OUTPUT_DIR}
            mkdir -p ${OUTPUT_DIR}
            if [[ "${PRECISION}" == "woq_int4" ]] && [[ "${MODEL_NAME}" == *"gpt"* ]]; then
                # Step 1: Generate modified weights and quantization info and save as checkpoint
                echo "Run quantization info: python run_gptq.py --model ${MODEL_NAME} --output-dir ${OUTPUT_DIR}"
                eval python ../run_gptq.py --model ${MODEL_NAME} --output-dir ${OUTPUT_DIR}

                # Step 2: Generate quantized model with INT4 weights
                echo "Run quantization: python single_instance/run_quantization.py --ipex-weight-only-quantization \
                --quant-with-amp --output-dir ${OUTPUT_DIR} -m ${MODEL_NAME} --low-precision-checkpoint ${OUTPUT_DIR}/gptq_checkpoint_g128.pt"
                eval python single_instance/run_quantization.py --ipex-weight-only-quantization \
                --quant-with-amp --output-dir ${OUTPUT_DIR} -m ${MODEL_NAME} --low-precision-checkpoint ${OUTPUT_DIR}/gptq_checkpoint_g128.pt

            # Generate quantized model with static_int8
            elif [[ "${PRECISION}" == "static_int8" ]]; then
                echo "Run quantization: python single_instance/run_quantization.py --ipex-smooth-quant --alpha auto \
                -m ${MODEL_NAME} --output-dir ${OUTPUT_DIR}"
                eval python single_instance/run_quantization.py --ipex-smooth-quant --alpha auto \
                -m ${MODEL_NAME} --output-dir ${OUTPUT_DIR}
            fi
        fi
    fi 
}

source activate llm

SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
# NUMA_NODES=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'| tr -d "[:space:]"`
NUMA_NODES=`lscpu | grep  "NUMA node.*CPU(s).*[0-9]$" | wc -l`
CORES_PER_NUMA=$(( $SOCKETS * $CORES_PER_SOCKET / $NUMA_NODES ))

if [ "${CORES_PER_INSTANCE}" ] && [ "${CORES_PER_INSTANCE}" -lt "${CORES_PER_NUMA}" ] && [ "${CORES_PER_INSTANCE}" -gt "0" ]; then
    CORES_PER_INSTANCE=${CORES_PER_INSTANCE}
    echo "CORES_PER_INSTANCE: ${CORES_PER_INSTANCE}"
else
    CORES_PER_INSTANCE=${CORES_PER_NUMA}
    echo "CORES_PER_INSTANCE: ${CORES_PER_NUMA}"
fi

# not support 
if [[ "${PRECISION}" == "woq_int4" ]]; then
    if [[ "${MODEL_NAME}" == *"chatglm"* ]] || [[ "${MODEL_NAME}" == *"baichuan"* ]] || [[ "${MODEL_NAME}" == *"flan-t5"* ]] || [[ "${MODEL_NAME}" == *"mpt"* ]]; then
        echo "Run error, Precision ${PRECISION} do not support for ${MODEL_NAME}."
        exit 1
    fi
elif [[ "${PRECISION}" == "woq_int8" ]] || [[ "${PRECISION}" == "static_int8" ]]; then
    if [[ "${MODEL_NAME}" == *"mpt"* ]]; then
        echo "Run error, Precision ${PRECISION} do not support for ${MODEL_NAME}."
        exit 1
    fi
fi

# base args
if [ "${MODE}" == "accuracy" ]; then
    EXEC_ARGS=" -m ${MODEL_NAME} --tasks 'lambada_openai' --batch-size ${BATCH_SIZE}"
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

# quantization for precision woq_int4 static_int8
quantization_model

# quantization for precision woq_int8 and mode accuracy
if [[ "${PRECISION}" == "woq_int8" ]] && [[ "${MODE}" == "accuracy" ]];then
    echo "Run quantization: python single_instance/run_quantization.py --ipex-weight-only-quantization \
    --quant-with-amp --weight-dtype INT8 -m ${MODEL_NAME} --output-dir saved_result"
    eval python single_instance/run_quantization.py --ipex-weight-only-quantization \
    --quant-with-amp --weight-dtype INT8 -m ${MODEL_NAME} --output-dir saved_result
fi
# greedy or beam search
if [ "$GREEDY" == "True" ]; then
    EXEC_ARGS+=" --greedy"
    echo "BEAM: 1"
else
    echo "BEAM: 4" 
fi

# precision args
if [[ "${PRECISION}" == "bfloat16" ]]; then
    EXEC_ARGS+=" --dtype bfloat16 --ipex"
fi

if [[ "${PRECISION}" == "float32" ]]; then
    EXEC_ARGS+=" --dtype float32 --ipex"
fi

if [[ "${MODE}" == "accuracy" ]]; then
    if [[ "${PRECISION}" == *"int"* ]]; then 
        EXEC_ARGS+=" --dtype int8"
        if [[ "${PRECISION}" == "woq_int4" ]] || [[ "${PRECISION}" == "static_int8" ]] ; then
            EXEC_ARGS+=" --quantized-model-path ${OUTPUT_DIR}/best_model.pt"
        fi
    fi
else
    if [[ "${PRECISION}" == "woq_int8" ]]; then
        EXEC_ARGS+=" --ipex-weight-only-quantization --weight-dtype INT8 --quant-with-amp"
    elif [[ "${PRECISION}" == "woq_int4" ]]; then
        if [[ "${MODEL_NAME}" == *"gpt"* ]]; then
            EXEC_ARGS+=" --quant-with-amp --quantized-model-path ${OUTPUT_DIR}/best_model.pt"
        else
            EXEC_ARGS+=" --ipex-weight-only-quantization --weight-dtype INT4 --quant-with-amp"
        fi
    elif [[ "${PRECISION}" == "static_int8" ]]; then
        EXEC_ARGS+=" --alpha auto --quantized-model-path ${OUTPUT_DIR}/best_model.pt"
    fi  
fi

# script name
if [ "${MODE}" == "accuracy" ]; then
    EVAL_SCRIPT="python single_instance/run_accuracy.py"
elif [[ "${PRECISION}" == "static_int8" ]]; then
    EVAL_SCRIPT="python single_instance/run_quantization.py"
elif [[ "${PRECISION}" == "woq_int4" ]] && [[ "${MODEL_NAME}" == *"gpt"* ]]; then
    EVAL_SCRIPT="python single_instance/run_quantization.py"
else
    EVAL_SCRIPT="python run.py"
fi

# execute benchmarking script
echo "Start case topology"
start_core=$(( $NUMA_NODES_USE * $CORES_PER_NUMA ))
end_core=$(( $start_core + $CORES_PER_INSTANCE - 1 ))
NUMA_ARGS="OMP_NUM_THREADS=${CORES_PER_INSTANCE} numactl -m ${NUMA_NODES_USE} -C ${start_core}-${end_core}"
EXEC_CMD="${NUMA_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}"
if [[ "${MODEL_NAME}" == *"deepseek"* ]]; then
    EXEC_CMD="${EVAL_SCRIPT} ${EXEC_ARGS}"
fi
echo "Run benchmark: ${EXEC_CMD}"
eval ${EXEC_CMD} ||
if [ $? -ne 0 ]; then
    if ([[ "${PRECISION}" == "woq_int4" ]] && [[ "${MODEL_NAME}" == *"gpt"* ]]) || [[ "${PRECISION}" == "static_int8" ]]; then
        echo "Run error, Try to delete the model and quantization it."
        rm -rf ${OUTPUT_DIR}/best_model.pt
        quantization_model
        echo "Run benchmark again: ${EXEC_CMD}"
        eval ${EXEC_CMD}
    fi
fi
echo "Finish case topology"
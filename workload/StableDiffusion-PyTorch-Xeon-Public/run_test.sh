#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# specific setting, start
echo "PRECISION: "${PRECISION}
echo "MODE: ${MODE}"
echo "STEPS: ${STEPS}"
echo "BATCH_SIZE: ${BATCH_SIZE}"
echo "IMAGE_WIDTH: ${IMAGE_WIDTH}"
echo "IMAGE_HEIGHT: ${IMAGE_HEIGHT}"
echo "DNOISE_STEPS: ${DNOISE_STEPS}"
python -c "import torch; print(\"torch.version: \"+torch.__version__)"

export HF_HOME="/root/.cache/huggingface"
export HF_DATASETS_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_EVALUATE_OFFLINE=1
export TRANSFORMERS_CACHE=$HF_HOME/hub
export HF_HUB_OFFLINE=0

EVAL_SCRIPT="inference.py"

echo "BASE_MODEL_NAME: stable-diffusion"

ARGS="--model_name_or_path="${MODEL_NAME}" \
    --dataset_path="/home/workspace/coco" \
    -w ${WARMUP_STEPS} \
    -i ${STEPS} "
if [ "$MODE" == "accuracy" ]; then
    ARGS+=" --accuracy"
else
    ARGS+=" --benchmark"
fi

# precision
if [[ "${PRECISION}" == "bfloat16" ]]; then
    ARGS+=" --precision=bf16"
    echo "### running bf16 precision"
elif [[ "${PRECISION}" == "float32" ]]; then
    ARGS+=" --precision=fp32"
    echo "### running fp32 precision"
elif [[ "${PRECISION}" == "float16" ]]; then
    ARGS+=" --precision=fp16"
    echo "### running fp16 precision"
elif [[ "${PRECISION}" == "bfloat32" ]]; then
    ARGS+=" --precision=bf32"
    echo "### running bf32 precision"
else
    echo "Precision ${PRECISION} is not supported. Please choose bfloat16, float32, float16 or bfloat32."
    exit 1
fi

if [ "${TORCH_TYPE}" == "EAGER" ]; then
    echo "Framework: PyTorch"
    echo "RECIPE_TYPE: oob"
elif [ "${TORCH_TYPE}" == "IPEX-JIT" ]; then
    ARGS="$ARGS --ipex --jit"
    echo "Framework: PyTorch+IPEX"
    echo "RECIPE_TYPE: public"
elif [ "${TORCH_TYPE}" == "COMPILE-OPENVINO" ]; then
    ARGS="$ARGS --compile_openvino"
    echo "Framework: PyTorch+OPENVINO"
    echo "RECIPE_TYPE: public"
elif [ "${TORCH_TYPE}" == "COMPILE-IPEX" ]; then
    ARGS="$ARGS --compile_ipex"
    echo "Framework: PyTorch+IPEX"
    echo "RECIPE_TYPE: public"
elif [ "${TORCH_TYPE}" == "COMPILE-INDUCTOR" ]; then
    export TORCHINDUCTOR_FREEZING=1
    ARGS="$ARGS --compile_inductor"
    echo "Framework: PyTorch"
    echo "RECIPE_TYPE: oob"
else
    echo "Supported TORCH_TYPE must be 1 of: EAGER, IPEX-JIT, COMPILE-IPEX, COMPILE-INDUCTOR"
    exit 1
fi

SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOC=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
NUMA_NODES=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
TOTAL_CORES=$(( ${CORES_PER_SOC} * ${SOCKETS} ))
CORES_PER_NUMA=$(echo ${TOTAL_CORES} / ${NUMA_NODES} | bc)

echo "CORES_PER_INSTANCE: ${CORES_PER_NUMA}"

NUMA_ARGS="python -m torch.backends.xeon.run_cpu --throughput-mode"
if [ $USE_JEMALLOC == "True" ]; then
    NUMA_ARGS+=" --enable_jemalloc"
fi
if [ $USE_TCMALLOC == "True" ]; then
    NUMA_ARGS+=" --enable_tcmalloc"
fi
if [[ ${USE_TCMALLOC} == "True" ]] && [[ ${USE_JEMALLOC} == "True" ]]; then
    echo "Unable to set TCMalloc and JEMalloc at the same time."
    exit 1
fi

if [[ "${NUMA_NODES_USE}" != "all" ]]; then
    NUMA_ARGS+=" --rank ${NUMA_NODES_USE}"
fi

echo "Start case topology"

VARIANT=$(echo ${MODEL_NAME}|cut -d/ -f2)
VARIANT=${VARIANT,,}
VARIANT=$(echo $VARIANT|sed 's/_/-/g')
echo "MODEL_NAME: ${VARIANT}"

if [ "${ONEDNN_VERBOSE}" == "1" ]; then
    export ONEDNN_VERBOSE=1
fi
echo "Run cmd: ${NUMA_ARGS} ${EVAL_SCRIPT} ${ARGS}"
eval ${NUMA_ARGS} ${EVAL_SCRIPT} $ARGS

echo "Finish case topology"

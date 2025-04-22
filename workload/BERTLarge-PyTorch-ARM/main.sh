#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
shopt -s nocasematch


VERBOSE=${VERBOSE:-}
PRECISION=${PRECISION:-fp32}

DEFAULT_STEPS=${DEFAULT_STEPS:-1}
STEPS=${STEPS:-$DEFAULT_STEPS}
BATCH_SIZE=${BATCH_SIZE:-1}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-1}

BACKEND_ADDITIONAL_ARGS=${BACKEND_ADDITIONAL_ARGS:-}
BENCHMARK_ADDITIONAL_ARGS=${BENCHMARK_ADDITIONAL_ARGS:-}

BENCHMARK_SCRIPT="/home/workspace/pytorch_model/models_v2/pytorch/bert_large/inference/cpu/transformers/examples/legacy/question-answering/run_squad.py"
TOKENIZER="/home/bert_squad_model"
MODEL="/home/bert_squad_model"
PREDICT_FILE="${DATASET_PATH}/dev-v1.1.json"
ARGS="${BENCHMARK_SCRIPT} \
      --benchmark \
      --model_type bert \
      --model_name_or_path ${MODEL} \
      --tokenizer_name ${TOKENIZER} \
      --do_eval \
      --do_lower_case \
      --predict_file ${PREDICT_FILE} \
      --learning_rate 3e-5 \
      --num_train_epochs 2.0 \
      --doc_stride 128 \
      --output_dir /tmp \
      --per_gpu_eval_batch_size ${BATCH_SIZE} \
      --perf_begin_iter 15 \
      --inductor \
      --perf_run_iters ${STEPS}"

if [[ ${VERBOSE} ]]
then
    export DNNL_VERBOSE=1
    export OMP_DISPLAY_ENV=VERBOSE
fi

# for bfloat16 set it to BF16 or ANY: https://oneapi-src.github.io/oneDNN/v2.4/dev_guide_attributes_fpmath_mode.html#a-note-on-default-floating-point-math-mode
if [[ ${PRECISION} == "bf16" ]]
then
    export DNNL_DEFAULT_FPMATH_MODE=${DNNL_DEFAULT_FPMATH_MODE:-BF16}
    # Won't set --bf16, running with VERBOSE=1 prooved that FPMATH_MODE is enough for BF16 code paths
    # --bf16 reduced performance below FP32, while setting only FPMATH_MODE increases the performance over FP32
    # also --bf16 crashes jit patched script
    # ARGS+=" --bf16"
fi

# Disable IOMP with --disable-iomp, because it overrides OMP parameters advised by AWS
CMD="python3 -m torch.backends.xeon.run_cpu --ncores_per_instance ${CORES_PER_INSTANCE} --skip_cross_node_cores --disable-iomp ${BACKEND_ADDITIONAL_ARGS} ${ARGS}"

TORCH_VER=$(python -c "import torch; print(torch.__version__)")
PYTHON_VER=$(python -V)
LOG_NAME="${BENCHMARK}_${PRECISION}_bs${BATCH_SIZE}_cpi${CORES_PER_INSTANCE}_$(date +%y-%m-%d-%H-%M-%S)"

echo "################### PARAMS"
echo "CMD=${CMD}"
echo "BATCH_SIZE=${BATCH_SIZE}"
echo "CORES_PER_INSTANCE=${CORES_PER_INSTANCE}"
echo "PRECISION=${PRECISION}"
echo "STEPS=${STEPS}"
echo "TORCH_VER=${TORCH_VER}"
echo "PYTHON_VER=${PYTHON_VER}"
echo "VERBOSE=${VERBOSE}"
echo "LOG_NAME=${LOG_NAME}"
echo "####################### ENV"
env
echo "####################### pip"
pip3 freeze
echo "###########################"

eval ${CMD}

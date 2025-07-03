#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
# source "$DIR"/ai_common/libs/precondition_check.sh

# activate llm environment
source activate llm
unset KMP_SETTINGS

MODEL_ID=$(echo ${MODEL_NAME}|cut -d "/" -f2)
echo "PLATFORM: ${TARGET_PLATFORM}"
echo "MODEL_NAME: ${MODEL_ID}"
echo "MODE: ${MODE}"
echo "STEPS: ${STEPS}"
echo "BATCH_SIZE: ${BATCH_SIZE}"
echo "INPUT_TOKENS: ${INPUT_TOKENS}"
echo "OUTPUT_TOKENS: ${OUTPUT_TOKENS}"
echo "MODEL_PATH: ${MODEL_PATH}"
echo "RANK_USE: ${RANK_USE}"
echo "PRECISION: ${PRECISION}"

if [[ "${MODEL_ID}" == *"gpt-j"* ]]; then
    echo "BASE_MODEL_NAME: gpt-j"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f3)"
elif [[ "${MODEL_ID}" == *"Llama-2"* ]]; then
    echo "BASE_MODEL_NAME: llama2"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f3)"
elif [[ "${MODEL_ID}" == *"Llama-3"* ]]; then
    echo "BASE_MODEL_NAME: llama3"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f4)"
else
    echo "BASE_MODEL_NAME: $(echo ${MODEL_ID}|cut -d "-" -f1)"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f2)"
fi

TORCH_VER=$(python -c "import torch; print(torch.__version__)")
PYTHON_VER=$(python -V)
LOG_NAME="${BENCHMARK}_${PRECISION}_bs${BATCH_SIZE}_cpi${CORES_PER_INSTANCE}_$(date +%y-%m-%d-%H-%M-%S)"


export HF_HOME="/root/.cache/huggingface"
export HF_DATASETS_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_EVALUATE_OFFLINE=1
export TRANSFORMERS_CACHE=$HF_HOME/hub


if [[ "${USE_DEEPSPEED}" == "True" ]]; then
    ./run_test_deepspeed.sh
else
    ./run_test_general.sh
fi
echo $?

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/precondition_check.sh

export MODE_WSF=${MODE}
# activate llm environment
source activate llm
source ./tools/env_activate.sh inference
export MODE=${MODE_WSF}
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
elif [[ "${MODEL_ID}" == *"gpt-neox"* ]]; then
    echo "BASE_MODEL_NAME: gpt-neox"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f3)"
elif [[ "${MODEL_ID}" == *"flan-t5"* ]]; then
    echo "BASE_MODEL_NAME: t5"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f3)"
elif [[ "${MODEL_ID}" == *"DeepSeek-R1-Distill-Llama-8B"* ]]; then
    echo "BASE_MODEL_NAME: Llama-8B"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f5)"
elif [[ "${MODEL_ID}" == *"Llama-3"* ]]; then
    echo "BASE_MODEL_NAME: llama3"
    if  [[ "${MODEL_ID}" == *"Llama-3.2"* ]]; then
        echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f3)"
    else
        echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f4)"
    fi
else
    echo "BASE_MODEL_NAME: $(echo ${MODEL_ID}|cut -d "-" -f1)"
    echo "MODEL_SIZE: $(echo ${MODEL_ID}|cut -d "-" -f2)"
fi

if [ "$ONEDNN_VERBOSE" == "1" ]; then
    export ONEDNN_VERBOSE=1
fi

#pytorch version
python -c "import torch; print(\"torch.version: \"+torch.__version__)"

export HF_HOME="/root/.cache/huggingface"
export HF_DATASETS_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_EVALUATE_OFFLINE=1
export TRANSFORMERS_CACHE=$HF_HOME/hub

if [[ "${MODEL_ID}" == *"chatglm"* ]]; then
    CONFIG_PATH="/root/.cache/huggingface/hub/models--THUDM--${MODEL_ID}/snapshots/*/config.json"
    if [ `grep -c "float16" $CONFIG_PATH` -ne '0' ]; then
        echo "sed -i 's/float16/float32/g' $CONFIG_PATH"
        sed -i 's/float16/float32/g' $CONFIG_PATH
    fi
fi

if [[ "${USE_DEEPSPEED}" == "True" ]]; then
    ./../run_test_deepspeed.sh
else
    ./../run_test_general.sh
fi
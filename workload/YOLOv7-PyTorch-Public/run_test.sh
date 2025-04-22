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
echo "HARDWARE: ${HARDWARE}"
python -c "import torch; print(\"torch.version: \"+torch.__version__)"

EVAL_SCRIPT="./test.py"

ARGS="--weights yolov7.pt"

ARGS="$ARGS --img 640 -e --data data/coco.yaml --conf-thres 0.001 --iou 0.65 --device cpu --batch-size $BATCH_SIZE "

if [ "${MDOE}" != "accuracy" ]; then
    ARGS+=" --performance"
fi

if [ $PRECISION == "bfloat16" ]; then
    ARGS+=" --bf16"
fi

if [ "${TORCH_TYPE}" == "EAGER" ]; then
    ARGS="$ARGS"
    echo "FRAMEWORK: PyTorch"
    echo "RECIPE_TYPE: public"
elif [ "${TORCH_TYPE}" == "COMPILE-IPEX" ]; then
    ARGS="$ARGS --ipex --inductor --jit"
    echo "FRAMEWORK: PyTorch+IPEX"
    echo "RECIPE_TYPE: public"
elif [ "${TORCH_TYPE}" == "COMPILE-INDUCTOR" ]; then
    ARGS="$ARGS --inductor --jit"
    echo "FRAMEWORK: PyTorch"
    echo "RECIPE_TYPE: public"
else
    echo "Supported TORCH_TYPE must be one of: EAGER, COMPILE-IPEX, COMPILE-INDUCTOR."
    exit 1
fi

SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOC=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
NUMA_NODES=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
TOTAL_CORES=$(( ${CORES_PER_SOC} * ${SOCKETS} ))
CORES_PER_NUMA=$(echo ${TOTAL_CORES} / ${NUMA_NODES} | bc)

if [[ ${CORES_PER_INSTANCE} -lt 0 ]] || [[ ${CORES_PER_INSTANCE} -gt ${CORES_PER_NUMA} ]]; then
    CORES_PER_INSTANCE=${CORES_PER_NUMA}
    echo "CORES_PER_INSTANCE: ${CORES_PER_NUMA}"
else
    echo "CORES_PER_INSTANCE: ${CORES_PER_INSTANCE}"
fi

NUMA_ARGS="python -m torch.backends.xeon.run_cpu --ncores-per-instance ${CORES_PER_INSTANCE}"

# accuracy setting
if [ ${MODE} == "accuracy" ]; then
    NUMA_ARGS+=" --rank 0"
fi

echo "Start case topology"

if [ "${ONEDNN_VERBOSE}" == "1" ]; then
    export ONEDNN_VERBOSE=1
fi
echo "Run cmd: ${NUMA_ARGS} ${EVAL_SCRIPT} ${ARGS}"
eval ${NUMA_ARGS} ${EVAL_SCRIPT} $ARGS

echo "Finish case topology"
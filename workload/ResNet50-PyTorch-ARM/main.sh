#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
shopt -s nocasematch

PRECISION=${PRECISION:-fp32}
STEPS=${STEPS:-1000}

BATCH_SIZE=${BATCH_SIZE:-1}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-1}

# Disable IOMP, because it overrided OMP parameters advised by AWS
BACKEND_ADDITIONAL_ARGS=${BACKEND_ADDITIONAL_ARGS:-"--disable-iomp"}
BENCHMARK_ADDITIONAL_ARGS=${BENCHMARK_ADDITIONAL_ARGS:-}
BENCHMARK_SCRIPT=/home/workspace/pytorch_model/models/image_recognition/pytorch/common/main.py

ARGS="--ncores_per_instance ${CORES_PER_INSTANCE} --skip_cross_node_cores ${BACKEND_ADDITIONAL_ARGS} ${BENCHMARK_SCRIPT} --dummy --steps=${STEPS} -a resnet50 -b ${BATCH_SIZE} -e -j 0 --seed 2020 --inductor ${BENCHMARK_ADDITIONAL_ARGS}"

# TORCH_MKLDNN_MATMUL_MIN_DIM=64 https://pytorch.org/tutorials/recipes/inference_tuning_on_aws_graviton.html
# TORCH_MKLDNN_MATMUL_MIN_DIM=1024 https://github.com/aws/aws-graviton-getting-started/blob/main/machinelearning/pytorch.md#troubleshooting-performance-issues
# export TORCH_MKLDNN_MATMUL_MIN_DIM=${TORCH_MKLDNN_MATMUL_MIN_DIM:-1024}
export LRU_CACHE_CAPACITY=1024
export THP_MEM_ALLOC_ENABLE=${THP_MEM_ALLOC_ENABLE:-1}

# for bfloat16 set it to BF16 or ANY: https://oneapi-src.github.io/oneDNN/v2.4/dev_guide_attributes_fpmath_mode.html#a-note-on-default-floating-point-math-mode
if [[ ${PRECISION} == "bf16" ]]
then
    export DNNL_DEFAULT_FPMATH_MODE=${DNNL_DEFAULT_FPMATH_MODE:-BF16}
    # Won't set --bf16, running with VERBOSE=1 prooved that FPMATH_MODE is enough for BF16 code paths
    # --bf16 reduced performance below FP32, while setting only FPMATH_MODE increases the performance over FP32
    # also --bf16 crashes jit patched script
    # ARGS+=" --bf16"
fi

# https://github.com/aws/aws-graviton-getting-started/blob/main/machinelearning/pytorch.md#runtime-configurations-for-optimal-performance
# OMP_NUM_THREADS is set by torch.backends.xeon.run_cpu --ncores_per_instance
export OMP_PROC_BIND=false
export OMP_PLACES=cores

# since IPEX leverages JIT it would be unfair to not use builtin pytorch jit
# JIT patch required to use --jit with --inductor
JIT_PATCH=${JIT_PATCH:-}
if [[ ${JIT_PATCH} ]]
then
    git -C /home/workspace/pytorch_model/ apply ${JIT_PATCH}
    git -C /home/workspace/pytorch_model/ diff
    ARGS+=" --jit"
fi

if [[ ${VERBOSE} ]]
then
    export DNNL_VERBOSE=1
    export OMP_DISPLAY_ENV=VERBOSE
fi

BENCH_SCRIPT="/home/workspace/pytorch_model/models/image_recognition/pytorch/common/main.py"

TORCH_VER=$(python -c "import torch; print(torch.__version__)")

# required to run, but not used (dummy dataset)
ARGS+=" /home/dataset/pytorch/resnet50 "
CMD="python -m torch.backends.xeon.run_cpu $ARGS"

echo "################### PARAMS"
echo "CMD=${CMD}"
echo "BATCH_SIZE=${BATCH_SIZE}"
echo "CORES_PER_INSTANCE=${CORES_PER_INSTANCE}"
echo "JIT_PATCH=${JIT_PATCH}"
echo "PRECISION=${PRECISION}"
echo "STEPS=${STEPS}"
echo "TORCH_VER=${TORCH_VER}"
echo "####################### ENV"
env
echo "###########################"

python3 -m torch.backends.xeon.run_cpu ${ARGS}
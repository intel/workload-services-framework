#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

source activate base

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/precondition_check.sh

# pytorch version, echo args use in kpi.sh
pytorch_ver=$(python -c "import torch; print(torch.__version__)")
echo "Torch_Version: $pytorch_ver"
echo "FUNCTION: ${FUNCTION}"
echo "MODE: ${MODE}"
echo "STEPS: ${STEPS}"
echo "BATCH_SIZE: ${BATCH_SIZE}"
echo "DATA_TYPE: ${DATA_TYPE}"

print_warning() {
    echo -e "--Precondition check result: PASSED"
    echo -e "--It's only checking for minimal case. Your case may still fail due to out of memory, it depends on your case settings" 
    print_end
}

precondition_check () {
    start_check
    print_warning
}

# setup knobs for benchmark test cases
socket_number=`lscpu | grep Socket | awk -F ':' '{print $2}'`
cores_per_socket=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
numa_number=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
total_cores=$(( $socket_number * $cores_per_socket ))
cores_per_numa=$(( $total_cores / $numa_number ))

if [[ "$PRECISION" == **"avx"** ]]; then
    export ONEDNN_MAX_CPU_ISA="AVX512_CORE_VNNI"
    if [ ${PRECISION} == "avx_int8" ]; then
        export ATEN_CPU_CAPABILITY="avx512_vnni"
        # Set env as a WA to make sure avx_int8 has the similar acc with amx_int8.
        export _DNNL_GRAPH_DISABLE_COMPILER_BACKEND="1"
    fi
elif [[ "$PRECISION" == **"amx"** ]]; then
    export ONEDNN_MAX_CPU_ISA="AVX512_CORE_AMX"
    if [ "${PRECISION}" == "amx_fp16" ]; then
        export ONEDNN_MAX_CPU_ISA="AVX512_CORE_AMX_FP16"
    fi
else
    echo "Input precision must include key words avx_ or amx_"
    exit 1
fi

if [ "${PLATFORM}" == "SRF" ]; then
    export ONEDNN_MAX_CPU_ISA="AVX2_VNNI_2"
fi

ARGS="--embedding_dim 128 \
    --dense_arch_layer_sizes 512,256,128 \
    --over_arch_layer_sizes 1024,1024,512,256,1 \
    --num_embeddings_per_feature 40000000,39060,17295,7424,20265,3,7122,1543,63,40000000,3067956,405282,10,2209,11938,155,4,976,14,40000000,40000000,40000000,590152,12973,108,36 \
    --epochs 1 \
    --pin_memory \
    --mmap_mode \
    --batch_size ${BATCH_SIZE} \
    --interaction_type=dcn \
    --dcn_num_layers=3 \
    --dcn_low_rank_dim=512 \
    --warmup_batches ${WARMUP_STEPS} \
    --limit_val_batches ${STEPS} \
    --log-freq 10 \
    --multi_hot_distribution_type uniform \
    --multi_hot_sizes 3,2,1,2,6,1,1,1,1,7,3,8,1,6,9,5,1,1,1,12,100,27,10,3,1,1"

if [[ "${PRECISION}" == **"bfloat16"** ]]; then
    ARGS+=" --dtype=bf16"
    echo "PRECISION: bfloat16"
elif [[ "${PRECISION}" == **"fp32"** ]]; then
    ARGS+=" --dtype=fp32"
    echo "PRECISION: float32"
elif [[ "${PRECISION}" == **"fp16"** ]]; then
    ARGS+=" --dtype=fp16"
    echo "PRECISION: float16"
elif [[ "${PRECISION}" == **"int8"** ]]; then
    ARGS+=" --dtype=int8 --int8-configure-dir int8_configure.json"
    echo "PRECISION: int8"
elif [[ "${PRECISION}" == **"bfloat32"** ]]; then
    ARGS+=" --dtype=bf32"
    echo "PRECISION: bfloat32"
else
    echo "Precision "${PRECISION}" is not supported in this workload."
    exit 1
fi
# ipex
if [ "${TORCH_TYPE}" == "IPEX" ]; then
    ARGS+=" --ipex-optimize --jit --ipex-merged-emb-cat"
    echo "FRAMEWORK: PyTorch+IPEX"
    echo "RECIPE_TYPE: dev"
fi
# inductor
if [ "${TORCH_TYPE}" == "COMPILE-INDUCTOR" ]; then
    export TORCH_INDUCTOR=1
    ARGS+=" --inductor"
    echo "FRAMEWORK: PyTorch"
    echo "RECIPE_TYPE: oob"
fi
# openvino
if [ "${TORCH_TYPE}" == "COMPILE-OPENVINO" ]; then
    ARGS+=" --openvino"
    echo "FRAMEWORK: PyTorch+OpenVINO"
    echo "RECIPE_TYPE: dev"
fi

NUMA_ARGS="python -m intel_extension_for_pytorch.cpu.launch --log_path logs"
if [ "$USE_JEMALLOC" == "True" ]; then
    NUMA_ARGS+=" --enable_jemalloc"
fi
if [ "$USE_TCMALLOC" == "True" ]; then
    NUMA_ARGS+=" --enable_tcmalloc"
fi
if [[ "${USE_TCMALLOC}" == "True" ]] && [[ "${USE_JEMALLOC}" == "True" ]]; then
    echo "Unable to set TCMalloc and JEMalloc at the same time."
    exit 1
fi
if [ "${NUMA_NODES_USE}" != "all" ]; then
    NUMA_ARGS+=" --node_id ${NUMA_NODES_USE}"
else
    NUMA_ARGS+=" --throughput_mode"
fi

if [ ${MODE} == "latency" ] || [ ${MODE} == "throughput" ]; then
    ARGS+=" --inference-only --benchmark"
fi
# onednn verbose
if [ "$ONEDNN_VERBOSE" == "1" ]; then
    export ONEDNN_VERBOSE=1
fi

echo "Start case topology"
echo "Run cmd: ${NUMA_ARGS} dlrm_main.py ${ARGS}"
eval ${NUMA_ARGS} dlrm_main.py ${ARGS}

echo "Finish case topology"

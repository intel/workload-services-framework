#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/information.sh
source "$DIR"/ai_common/libs/precheck.sh
source "$DIR"/ai_common/libs/set_env_pt.sh
source "$DIR"/ai_common/libs/pt_args.sh

SOCKETS=$(lscpu | grep "Socket(s):" | awk -F ':' '{print $2}' | xargs)
CORES_PER_SOCKET=$(lscpu | grep "Core(s) per socket:" | awk -F ':' '{print $2}' | xargs)
NUMAS=$(lscpu | grep "NUMA node(s):" | awk -F '[[:space:]]+' '{print $NF}' | xargs)
TOTAL_CORES=$((SOCKETS*CORES_PER_SOCKET))
CORES_PER_NUMA=$((TOTAL_CORES/NUMAS))

MODEL_DIR="/home/workspace/models"
OUTPUT_DIR="/home/workspace/models/output"
DATASET_DIR="/home/workspace/dataset"

if [ -z "${CORES_PER_INSTANCE}" ]; then
    CORES_PER_INSTANCE=${CORES_PER_NUMA}
fi

if [ "$MODE" == "throughput" ] && [ "$FUNCTION" == "inference" ]; then
    INSTANCE_NUMBER=$NUMAS
elif [ "$MODE" == "accuracy" ] && [ "$FUNCTION" == "inference" ]; then
    INSTANCE_NUMBER=$((CORES_PER_NUMA/CORES_PER_INSTANCE))
elif [ "$MODE" == "throughput" ] && [ "$FUNCTION" == "training" ]; then
    if [ "$DISTRIBUTED" == "True" ]; then
        INSTANCE_NUMBER=$((TOTAL_CORES/CORES_PER_INSTANCE))
    else
        INSTANCE_NUMBER=1
    fi
elif [ "$MODE" == "accuracy" ] && [ "$FUNCTION" == "training" ]; then
    INSTANCE_NUMBER=1
fi

python -c "import torch; print(\"torch.version: \"+torch.__version__)"

show_info () {
    start_show_info
    ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE WARMUP_STEPS STEPS DATA_TYPE CORES_PER_INSTANCE INSTANCE_NUMBER TRAIN_EPOCH CASE_TYPE WEIGHT_SHARING ONEDNN_VERBOSE CUSTOMER_ENV"
    if [ "${FUNCTION}" == "training" ] && [ "${MODE}" == "throughput" ]; then
        ALL_KEYS+=" DISTRIBUTED CCL_WORKER_COUNT"
    fi
    print_tested_params $ALL_KEYS
    print_lscpu
    end_show_info
}

precondition_check () {
    start_check
    if [ "$FUNCTION" == "inference" ]; then
        memory_needs=$(( 140 * $1 ))
    else
        memory_needs=300
    fi
    check_memory $memory_needs
    print_check_result
}

show_info
precondition_check $INSTANCE_NUMBER

# Set PT evl script
EVAL_SCRIPT="${MODEL_DIR}/models_v2/pytorch/dlrm/common/dlrm_s_pytorch.py"

# Set PT launch args
LAUNCH_ARGS="-m intel_extension_for_pytorch.cpu.launch \
--ncore_per_instance=${CORES_PER_INSTANCE} \
--ninstances=${INSTANCE_NUMBER} \
--log_path=${OUTPUT_DIR} \
--log_file_prefix=./dlrm_${MODE}_log_${PRECISION}"

EXEC_ARGS="--test-mini-batch-size=${BATCH_SIZE} \
--num-batches=${STEPS} \
--raw-data-file=${DATASET_DIR}/day0 \
--processed-data-file=${DATASET_DIR}/terabyte_processed.npz \
--data-set=terabyte \
--memory-map \
--mlperf-bin-loader \
--round-targets=True \
--learning-rate=1.0 \
--arch-embedding-size=39884406-39043-17289-7420-20263-3-7120-1543-63-38532951-2953546-403346-10-2208-11938-155-4-976-14-39979771-25641295-39664984-585935-12972-108-36 \
--arch-mlp-bot=13-512-256-128 \
--arch-mlp-top=1024-1024-512-256-1 \
--arch-sparse-feature-size=128 \
--max-ind-range=40000000 \
--ipex-interaction \
--numpy-rand-seed=727 \
--inference-only \
--print-freq=100 \
--num-warmup-iters=${WARMUP_STEPS} \
--print-time"

if [ "$WEIGHT_SHARING" == "True" ]; then
    EXEC_ARGS+=" --share-weight-instance=${CORES_PER_INSTANCE}"
fi

if [ "$MODE" == "throughput" ] && [ "$FUNCTION" == "inference" ]; then
    if [ "$CORES_PER_INSTANCE" == "$CORES_PER_NUMA" ]; then
        LAUNCH_ARGS+=" --throughput_mode"
    fi
    EXEC_ARGS+=" --mini-batch-size=128"
elif [ "$MODE" == "accuracy" ] && [ "$FUNCTION" == "inference" ]; then
    export OMP_NUM_THREADS=$CORES_PER_INSTANCE
    LAUNCH_ARGS+=" --node_id=0"
    EXEC_ARGS+=" --load-model=${WEIGHT_PATH}/tb00_40M.pt --test-freq=2048 --print-auc --mini-batch-size=2048"
elif [ "$MODE" == "throughput" ] && [ "$FUNCTION" == "training" ]; then
    if [ "${DISTRIBUTED}" == "True" ]; then
        source /root/anaconda3/lib/python3.10/site-packages/oneccl_bindings_for_pytorch/env/setvars.sh
        LAUNCH_ARGS=${LAUNCH_ARGS//--memory-allocator=jemalloc/--memory-allocator=tcmalloc}
        LAUNCH_ARGS=${LAUNCH_ARGS//--ninstances=${INSTANCE_NUMBER}/--nnodes=1}
        LAUNCH_ARGS=${LAUNCH_ARGS//--ncore_per_instance=${CORES_PER_INSTANCE}/--nproc_per_node=${INSTANCE_NUMBER}}
        LAUNCH_ARGS+=" --ccl_worker_count=${CCL_WORKER_COUNT} --logical_core_for_ccl"
        LAUNCH_ARGS+=" --skip_cross_node_cores --distributed"
    else
        export OMP_NUM_THREADS=$CORES_PER_INSTANCE
        LAUNCH_ARGS+=" --node_id=0"
    fi
    EXEC_ARGS=${EXEC_ARGS//--inference-only }
    EXEC_ARGS+=" --mlperf-auc-threshold=0.8025 --print-auc --ipex-merged-emb --mini-batch-size=${BATCH_SIZE}"
elif [ "$MODE" == "accuracy" ] && [ "$FUNCTION" == "training" ]; then
    export OMP_NUM_THREADS=$CORES_PER_INSTANCE
    LAUNCH_ARGS+=" --node_id=0"
    EXEC_ARGS=${EXEC_ARGS//--inference-only }
    EXEC_ARGS=${EXEC_ARGS//"--test-mini-batch-size=${BATCH_SIZE}"/"--test-mini-batch-size=262144"}
    EXEC_ARGS+=" --mlperf-auc-threshold=0.8025 --print-auc --ipex-merged-emb --mini-batch-size=${BATCH_SIZE} --mlperf-bin-shuffle --should-test --test-freq=6400"
fi

# Set memory allocator
if [ "$MODE" == "accuracy" ] && [ "$FUNCTION" == "training" ]; then
    LAUNCH_ARGS+=" --memory-allocator=tcmalloc"
else 
    LAUNCH_ARGS+=" --memory-allocator=jemalloc"
fi

# Set args for avx/amx and fp32/bf16/bf32/int8
case ${PRECISION} in
    "avx_fp32" )
        unset DNNL_MAX_CPU_ISA
        export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
    ;;
    "avx_int8" )
        if [ "$FUNCTION" == "training" ]; then
            echo "** For training, only support avx_fp32 and amx_bfloat16 **"
            exit 1
        fi
        unset DNNL_MAX_CPU_ISA
        export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
        EXEC_ARGS+=" --num-cpu-cores=${CORES_PER_NUMA} --int8 --int8-configure=${MODEL_DIR}/models/recommendation/pytorch/dlrm/product/int8_configure.json"
    ;;
    "amx_bfloat16" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --bf16"
    ;;
    "amx_int8" )
        if [ "$FUNCTION" == "training" ]; then
            echo "** For training, only support avx_fp32 and amx_bfloat16 **"
            exit 1
        fi
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --num-cpu-cores=${CORES_PER_NUMA} --int8 --int8-configure=${MODEL_DIR}/models/recommendation/pytorch/dlrm/product/int8_configure.json"
    ;;
    "amx_bfloat32" )
        if [ "$FUNCTION" == "training" ]; then
            echo "** For training, only support avx_fp32 and amx_bfloat16 **"
            exit 1
        fi
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --bf32"
    ;;
    * )
        echo "** Invalid Precision: ${PRECISION} **"
        exit 1
    ;;
esac

# Run benchmark
echo "command: python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS} "
python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}
echo "Complete..."

#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/set_env_pt.sh
source "$DIR"/ai_common/libs/precheck.sh
source "$DIR"/ai_common/libs/run_cmd.sh

INSTANCE_NUMBER=$(echo ${TOTAL_CORES} / ${CORES_PER_INSTANCE} | bc)
# Split ISA & precision
ISA=$(echo ${PRECISION}|cut -d_ -f1)
INPUT_PRECISION=$(echo ${PRECISION}|cut -d_ -f2)

print_tested_params() {
    print_subtitle "Test Parameters Used"

    for i in "$@"; do
        echo -e $i": "${!i}
    done

    print_end
}

# Precheck
function show_info() {
    start_show_info
    ALL_KEYS=$@
    print_tested_params $ALL_KEYS
    print_lscpu
    end_show_info
}

ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS DATA_TYPE CORES_PER_INSTANCE INSTANCE_NUMBER WEIGHT_SHARING TRAIN_EPOCHS CASE_TYPE MAX_SEQ_LENGTH ONEDNN_VERBOSE MAX_CPU_ISA CUSTOMER_ENV WARMUP_STEPS"
show_info ${ALL_KEYS}
precondition_check $BATCH_SIZE $INSTANCE_NUMBER
set_pt_ISA_env

if [ "$MODE" == "throughput" ] && [ "$FUNCTION" == "inference" ] && [ "$TOPOLOGY" == "dlrm" ]; then
    pt_OMP_env_cmd="OMP_NUM_THREADS=1"
else
    pt_OMP_env_cmd="OMP_NUM_THREADS=${CORES_PER_INSTANCE}"
fi

echo "Set ENV ${pt_OMP_env_cmd}"
export ${pt_OMP_env_cmd}

if [ "${ONEDNN_VERBOSE}" == "True" ]; then
    pt_verbose_value="DNNL_VERBOSE=1, MKLDNN_VERBOSE=1"
else
    pt_verbose_value="DNNL_VERBOSE=0, MKLDNN_VERBOSE=0"
fi
echo "Set ENV ${pt_verbose_value}"
export ${pt_verbose_value}

# set ld kmp_b kmp_a ENV
export kmp_b="KMP_BLOCKTIME=1"
export kmp_a="KMP_AFFINITY=granularity=fine,compact,1,0"
export ld="LD_PRELOAD=/root/lib/jemalloc/lib/libjemalloc.so:/root/anaconda3/lib/libiomp5.so"

#pytorch version
pytorch_ver=$(python -c "import torch; print(torch.__version__)")
echo "Torch_Version: $pytorch_ver"

LAUNCH_ARGS=" --memory-allocator=jemalloc \
              --log_file_prefix=${TOPOLOGY}_log_${FUNCTION}_${MODE}_${PRECISION}_bs_${BATCH_SIZE}_${DATA_TYPE}"

if [ "$FUNCTION" == "inference" ] ; then
    if [ "$MODE" == "latency" ]; then
        if [[ "$WEIGHT_SHARING" == "True" ]]; then
            LAUNCH_ARGS+=" --ninstances ${NUMA_NODES}"
        elif [ -n "$CORES_PER_INSTANCE"  ]; then
            LAUNCH_ARGS+=" --ncores-per-instance ${CORES_PER_INSTANCE}\
                    --ninstances ${INSTANCE_NUMBER}"
        else
            LAUNCH_ARGS+=" --latency_mode"
        fi
    elif [ "$MODE" == "throughput" ]; then
        if [ -n "$CORES_PER_INSTANCE" ]; then
            LAUNCH_ARGS+=" --ncores-per-instance ${CORES_PER_INSTANCE}\
                    --ninstances ${INSTANCE_NUMBER}"
        else
            LAUNCH_ARGS+=" --throughput_mode"
        fi
    elif [ "$MODE" == "accuracy" ]; then
        if [ -n "$CORES_PER_INSTANCE" ]; then
            LAUNCH_ARGS+=" --ncores-per-instance ${CORES_PER_INSTANCE}  \
                    --ninstances 1"
        else
            LAUNCH_ARGS+=" --node_id 0"
        fi
    fi
elif [ "$FUNCTION" == "training" ]; then
    LAUNCH_ARGS+=" --node_id 0"
    if [ -n "$CORES_PER_INSTANCE" ]; then
        LAUNCH_ARGS+=" --ncores-per-instance ${CORES_PER_INSTANCE} \
                --ninstances 1"
    fi
else
    echo "Error, not support function ${FUNCTION}"
    exit 1
fi

ARGS=" --use_ipex \
    --train_file ${DATASET_DIR}/SST-2/train.csv \
    --validation_file ${DATASET_DIR}/SST-2/dev.csv \
    --jit_mode \
    --model_name_or_path ${MODEL_DIR} \
    --do_eval \
    --max_seq_length ${MAX_SEQ_LENGTH} \
    --output_dir ./tmp" \

if [ $PRECISION == "amx_int8" ]; then
    ARGS+=" --int8 \
            --bf16 \
            --int8_config configure.json"
elif [ $PRECISION == "amx_bfloat16" ]; then
    ARGS+=" --bf16"
elif [ $PRECISION == "amx_bfloat32" ]; then
    ARGS+=" --bf32 \
            --auto_kernel_selection"
elif [ $PRECISION == "avx_int8" ]; then
    ARGS+=" --int8 \
            --int8_config configure.json"
fi

if [ "$FUNCTION" == "inference" ] ; then
    ARGS+=" --per_device_eval_batch_size ${BATCH_SIZE} \
           --perf_run_iters ${STEPS}"
    if [ "$MODE" == "throughput" ]; then
        ARGS+=" --perf_begin_iter ${WARMUP_STEPS} \
               --benchmark"
    elif [ "$MODE" == "latency" ]; then
        ARGS+=" --perf_begin_iter ${WARMUP_STEPS} \
                --benchmark"
        if [ "$WEIGHT_SHARING" == "True" ]; then
            ARGS+=" --use_share_weight \
                    --total_cores ${CORES_PER_NUMA}"
            if [ -n "$CORES_PER_INSTANCE" ]; then
                ARGS+=" --cores_per_instance ${CORES_PER_INSTANCE}"
            else
                ARGS+=" --cores_per_instance 4"
            fi
        fi
    fi
elif [ "$FUNCTION" == "training" ]; then
    echo "DistilBERT not support training ${FUNCTION}"
    exit 1
else
    echo "Error, not support function ${FUNCTION}"
    exit 1
fi

EVAL_SCRIPT=${EVAL_SCRIPT:-"./transformers/examples/pytorch/text-classification/run_glue.py"}
echo "Running python -m intel_extension_for_pytorch.cpu.launch ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${ARGS}"

echo "Running"
export HF_DATASETS_OFFLINE=1
python -m intel_extension_for_pytorch.cpu.launch ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${ARGS}

echo "Finish case topology"

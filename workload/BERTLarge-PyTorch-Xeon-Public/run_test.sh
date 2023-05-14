#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/information.sh
source "$DIR"/ai_common/libs/precondition_check.sh

if [[ "$*" =~ "latency" ]]; then
    CORE_NR=$(cat /proc/cpuinfo | grep -c processor)
    if [ $CORE_NR -lt 4 ]; then
        echo "Detect cpu core number: $CORE_NR, No suffient CPU resource to run latency case!"
        exit -1;
    fi
fi

socket_number=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
cores_per_socket=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
numa_nodes=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
total_cores=$((socket_number*cores_per_socket))
cores_per_numa=$((total_cores/numa_nodes))


if [ "$CORES_PER_INSTANCE" ]; then
    CORES_PER_INSTANCE=$CORES_PER_INSTANCE
else
    CORES_PER_INSTANCE=$cores_per_numa
fi

if [ -z "${INSTANCE_NUMBER}" ]; then
    INSTANCE_NUMBER=$((total_cores/CORES_PER_INSTANCE))
fi

# Inefficient memory will not lead to running fail directly, but will cause throughput drop.
memory_needs=$(expr ${INSTANCE_NUMBER} \* 2)

show_info () {
    start_show_info
    ALL_KEYS="MODE PLATFORM TOPOLOGY PRECISION FUNCTION DATA_TYPE WARMUP_STEPS STEPS BATCH_SIZE CORES_PER_INSTANCE INSTANCE_NUMBER WEIGHT_SHARING ONEDNN_VERBOSE ENABLE_PROFILING MAX_SEQ_LENGTH CUSTOMER_ENV"
    print_tested_params $ALL_KEYS
    print_lscpu
    end_show_info
}

precondition_check () {
    start_check
    check_memory $memory_needs
    print_check_result
}

show_info
precondition_check

log_path="/home/log/pytorch/instance_logs"
log_file_prefix="${TOPOLOGY}_log_${FUNCTION}_${MODE}_${PRECISION}_bs_${BATCH_SIZE}_${DATA_TYPE}"
LAUNCH_ARGS="-m intel_extension_for_pytorch.cpu.launch --enable_jemalloc --log_path=${log_path} --log_file_prefix=${log_file_prefix} --ncore_per_instance=${CORES_PER_INSTANCE} --ninstances=${INSTANCE_NUMBER}"
EXEC_ARGS="--per_gpu_eval_batch_size=${BATCH_SIZE} --perf_run_iters=${STEPS} --benchmark --model_type=bert --model_name_or_path=${FINETUNED_MODEL} \
           --tokenizer_name=${FINETUNED_MODEL} --do_eval --do_lower_case --predict_file=${EVAL_DATA_FILE} --learning_rate=3e-5 \
           --num_train_epochs=2.0 --max_seq_length=${MAX_SEQ_LENGTH} --doc_stride=128 --output_dir=./tmp --perf_begin_iter=${WARMUP_STEPS} --use_jit \
           --int8_config=/home/workspace/quickstart/language_modeling/pytorch/bert_large/inference/cpu/configure.json"

if [ "${MODE}" == "accuracy" ]; then
    EXEC_ARGS=${EXEC_ARGS//--benchmark }
fi

# Set the OMP environment
if [ -n "${CORES_PER_INSTANCE}" ]; then
    export OMP_NUM_THREADS=${CORES_PER_INSTANCE}
fi

# Set environment for oneDNN verbose
if [ -n "${ONEDNN_VERBOSE}" ] && [ "${ONEDNN_VERBOSE}" == "1" ]; then
    export DNNL_VERBOSE=1
    export MKLDNN_VERBOSE=1
else
    export DNNL_VERBOSE=0
    export MKLDNN_VERBOSE=0
fi

# Set environment and args for avx/amx and fp32/bf16/bf32/int8
case ${PRECISION} in
    "avx_fp32" )
        unset DNNL_MAX_CPU_ISA
        export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
    ;;
    "avx_int8" )
        unset DNNL_MAX_CPU_ISA
        export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
        EXEC_ARGS+=" --int8 --int8_fp32"
    ;;
    "amx_bfloat16" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --bf16"
    ;;
    "amx_int8" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --int8"
    ;;
    "amx_bfloat32" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --bf32"
    ;;
    * )
        echo "** Invalid Precision: ${PRECISION} **"
        exit 1
    ;;
esac

if [ "${WEIGHT_SHARING}" == "True" ]; then
    EXEC_ARGS+=" --use_share_weight --total_cores=${cores_per_numa} --cores_per_instance=${CORES_PER_INSTANCE}"
fi

echo "command: python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}"
python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}
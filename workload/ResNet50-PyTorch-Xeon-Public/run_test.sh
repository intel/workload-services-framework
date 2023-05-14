#! /bin/bash

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/precheck.sh
source "$DIR"/ai_common/libs/set_env_pt.sh

SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
NUMAS=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
TOTAL_CORES=$(( $SOCKETS * $CORES_PER_SOCKET ))
CORES_PER_NUMA=$(( $TOTAL_CORES / $NUMAS ))
INSTANCES_PER_SOCKET=$(( $CORES_PER_SOCKET / $CORES_PER_INSTANCE ))
INSTANCES=$(( $INSTANCES_PER_SOCKET * $SOCKETS ))
MODEL_DIR="/home/workspace/models"
OUTPUT_DIR="/home/workspace/models/output"
DATA_DIR="/home/workspace/dataset"
INT8_CONFIG="${MODEL_DIR}/models/image_recognition/pytorch/common/resnet50_configure_sym.json"


show_info "WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE WARMUP_STEPS STEPS DATA_TYPE CORES_PER_INSTANCE CASE_TYPE WEIGHT_SHARING VERBOSE CUSTOMER_ENV"

precondition_check $BATCH_SIZE $INSTANCES

# Set env variable
set_pt_env
set_pt_verbose_env

# Set PT launch args
LAUNCH_ARGS=" -m intel_extension_for_pytorch.cpu.launch \
             --use_default_allocator --ninstance ${INSTANCES} \
             --ncore_per_instance ${CORES_PER_INSTANCE} \
             --log_path=${OUTPUT_DIR} \
             --log_file_prefix=./resnet50_${MODE}_log_${PRECISION}"

# Set PT evl script
EVAL_SCRIPT="${MODEL_DIR}/models/image_recognition/pytorch/common/main.py"

# Set PT exec args
EXEC_ARGS=" -a resnet50 ${DATA_DIR} \
            --ipex -j 0 -e --seed 2020 \
            --steps ${STEPS} -w ${WARMUP_STEPS} \
            -b ${BATCH_SIZE} \
            --configure-dir ${INT8_CONFIG}"

if [[ $MODE == "accuracy" ]]; then
    EXEC_ARGS+=" --pretrained"
fi

if [[ $DATA_TYPE == "dummy" ]]; then
    EXEC_ARGS+=" --dummy"
fi

# Set args for avx/amx and fp32/bf16/bf32/int8
case ${PRECISION} in
    "avx_fp32" )
        unset DNNL_MAX_CPU_ISA
        export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
        EXEC_ARGS+=" --jit"
    ;;
    "avx_int8" )
        unset DNNL_MAX_CPU_ISA
        export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
        EXEC_ARGS+=" --int8"
    ;;
    "amx_bfloat16" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --bf16 --jit"
    ;;
    "amx_int8" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --int8 "
    ;;
    "amx_bfloat32" )
        unset ONEDNN_MAX_CPU_ISA
        export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
        EXEC_ARGS+=" --bf32 --jit"
    ;;
    * )
        echo "** Invalid Precision: ${PRECISION} **"
        exit 1
    ;;
esac

# Run benchmark
echo "command: python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}"
python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}
echo "Complete..."
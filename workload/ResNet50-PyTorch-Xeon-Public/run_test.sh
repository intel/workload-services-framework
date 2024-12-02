#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/precheck.sh

# pytorch version, echo args use in kpi.sh
pytorch_ver=$(python -c "import torch; print(torch.__version__)")
echo "Torch_Version: $pytorch_ver"

SOCKETS=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}'`
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}'`
NUMAS=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}'`
TOTAL_CORES=$(( $SOCKETS * $CORES_PER_SOCKET ))
CORES_PER_NUMA=$(( $TOTAL_CORES / $NUMAS ))
MODEL_DIR="/home/workspace/models"
OUTPUT_DIR="/home/workspace/models/output"
DATA_DIR="/home/workspace/dataset"
INT8_CONFIG="${MODEL_DIR}/models/image_recognition/pytorch/common/resnet50_configure_sym.json"
INSTANCE_NUMBER=$((TOTAL_CORES/CORES_PER_INSTANCE))

show_info "WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE WARMUP_STEPS STEPS DATA_TYPE CORES_PER_INSTANCE CASE_TYPE WEIGHT_SHARING VERBOSE CUSTOMER_ENV TRAIN_EPOCH DISTRIBUTED INSTANCE_NUMBER CCL_WORKER"

precondition_check $BATCH_SIZE $INSTANCE_NUMBER

LAUNCH_ARGS=" -m intel_extension_for_pytorch.cpu.launch \
                --memory-allocator=jemalloc --ninstances=${INSTANCE_NUMBER} \
                --ncore_per_instance=${CORES_PER_INSTANCE} \
                --log_path=${OUTPUT_DIR} \
                --log_file_prefix=./resnet50_${MODE}_log_${PRECISION}"

if [ "${FUNCTION}" == "inference" ]; then

    # Set PT evl script
    EVAL_SCRIPT="${MODEL_DIR}/models/image_recognition/pytorch/common/main.py"

    # Set PT exec args
    EXEC_ARGS=" -a resnet50 ${DATA_DIR} \
                -j 0 -e --seed 2020 \
                --steps ${STEPS} -w ${WARMUP_STEPS} \
                -b ${BATCH_SIZE} \
                --configure-dir ${INT8_CONFIG}"

    if [[ $MODE == "accuracy" ]]; then
        EXEC_ARGS+=" --pretrained"
    fi

    if [[ $DATA_TYPE == "dummy" ]]; then
        EXEC_ARGS+=" --dummy"
    fi
    
    if [[ $TORCH_TYPE == "COMPILE-INDUCTOR" ]]; then
        EXEC_ARGS+=" --inductor"
        echo "FRAMEWORK: PyTorch"
        echo "RECIPE_TYPE: oob"
    elif [[ $TORCH_TYPE == "IPEX" ]]; then
        EXEC_ARGS+=" --ipex"
        echo "FRAMEWORK: PyTorch+IPEX"
        echo "RECIPE_TYPE: Public"
    else    
        echo "FRAMEWORK: PyTorch"
        echo "RECIPE_TYPE: oob"
    fi

    # Set args for avx/amx and fp32/bf16/bf32/int8
    case ${PRECISION} in
        "avx_fp32" )
            INPUT_PRECISION=""
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
            INPUT_PRECISION=--bf16
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
        "avx_bfloat16" )
            INPUT_PRECISION=--bf16
            unset ONEDNN_MAX_CPU_ISA
            export DNNL_MAX_CPU_ISA=avx512_core_vnni
            EXEC_ARGS+=" --bf16 --jit"
        ;;
        * )
            echo "** Invalid Precision: ${PRECISION} **"
            exit 1
        ;;
    esac

    echo "command: python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}"
    python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}
fi

# Run benchmark

if [ "${FUNCTION}" == "training" ]; then
    EXEC_ARGS="-a resnet50 ${DATA_DIR}\
               --ipex \
               -j 0 \
               --seed 2020 \
               --epochs ${TRAIN_EPOCH} \
               --training_steps ${STEPS} \
               --train-no-eval \
               -w 50 \
               -b ${BATCH_SIZE}"
    # Set environment and args for avx/amx and fp32/bf16/bf32/int8
    case ${PRECISION} in
        "avx_fp32" )
            unset DNNL_MAX_CPU_ISA
            export ONEDNN_MAX_CPU_ISA=avx512_core_vnni
        ;;
        "amx_bfloat16" )
            unset ONEDNN_MAX_CPU_ISA
            export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
            EXEC_ARGS+=" --bf16"
        ;;
        "amx_bfloat32" )
            unset ONEDNN_MAX_CPU_ISA
            export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
            EXEC_ARGS+=" --bf32"
        ;;
        "avx_bfloat16" )
            unset ONEDNN_MAX_CPU_ISA
            export DNNL_MAX_CPU_ISA=avx512_core_vnni
            EXEC_ARGS+=" --bf16"
        ;;
        * )
            echo "** Invalid Precision for Training: ${PRECISION} **"
            exit 1
        ;;
    esac
    TRAIN_SCRIPT="${MODEL_DIR}/models/image_recognition/pytorch/common/main.py"
    LAUNCH_ARGS=${LAUNCH_ARGS//}
    if [ "${DISTRIBUTED}" == "True" ]; then
        source /root/anaconda3/lib/python3.10/site-packages/oneccl_bindings_for_pytorch/env/setvars.sh
        LAUNCH_ARGS=${LAUNCH_ARGS//--ninstances=${INSTANCE_NUMBER}/--nnodes=1}
        LAUNCH_ARGS=${LAUNCH_ARGS//--ncore_per_instance=${CORES_PER_INSTANCE}/--nproc_per_node=${INSTANCE_NUMBER}}
        LAUNCH_ARGS=${LAUNCH_ARGS//--memory-allocator=jemalloc/--memory-allocator=tcmalloc}
        LAUNCH_ARGS+=" --ccl_worker_count ${CCL_WORKER} --logical_core_for_ccl"
        LAUNCH_ARGS+=" --skip_cross_node_cores --distributed"
    else
        LAUNCH_ARGS=${LAUNCH_ARGS//--ninstances=${INSTANCE_NUMBER}/--ninstances=1}
    fi

    echo "command: python ${LAUNCH_ARGS} ${TRAIN_SCRIPT} ${EXEC_ARGS}"
    python ${LAUNCH_ARGS} ${TRAIN_SCRIPT} ${EXEC_ARGS}
fi

echo "Complete..."

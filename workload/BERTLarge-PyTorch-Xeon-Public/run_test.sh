#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/information.sh
source "$DIR"/ai_common/libs/precondition_check.sh

# pytorch version, echo args use in kpi.sh
pytorch_ver=$(python -c "import torch; print(torch.__version__)")
echo "Torch_Version: $pytorch_ver"
echo "Seq_Length: $MAX_SEQ_LENGTH"

if [[ "$*" =~ "latency" ]]; then
    CORE_NR=$(cat /proc/cpuinfo | grep -c processor)
    if [ $CORE_NR -lt 4 ]; then
        echo "Detect cpu core number: $CORE_NR, No suffient CPU resource to run latency case!"
        exit -1;
    fi
fi

socket_number=`lscpu | grep "Socket(s)" | awk -F ':' '{print $2}' | tr -d '[:space:]'`
cores_per_socket=`lscpu | grep "Core(s) per socket" | awk -F ':' '{print $2}' | tr -d '[:space:]'`
numa_nodes=`lscpu | grep "NUMA node(s)" | awk -F ':' '{print $2}' | tr -d '[:space:]'`
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
    if [ "${FUNCTION}" == "training" ]; then
        ALL_KEYS+=" DISTRIBUTED"
        if [ "${DISTRIBUTED}" == "True" ]; then
            ALL_KEYS+=" NNODES CCL_WORKER_COUNT"
        fi
    fi
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

if [ "${FUNCTION}" == "inference" ]; then

    EXEC_ARGS="--per_gpu_eval_batch_size=${BATCH_SIZE} --perf_run_iters=${STEPS} --benchmark --model_type=bert --model_name_or_path=${FINETUNED_MODEL} \
           --tokenizer_name=${FINETUNED_MODEL} --do_eval --do_lower_case --predict_file=${EVAL_DATA_FILE} --learning_rate=3e-5 \
           --num_train_epochs=2.0 --max_seq_length=${MAX_SEQ_LENGTH} --doc_stride=128 --output_dir=./tmp --perf_begin_iter=${WARMUP_STEPS} --use_jit \
           --int8_config=/home/workspace/quickstart/language_modeling/pytorch/bert_large/inference/cpu/configure.json"

    if [ "${MODE}" == "accuracy" ]; then
        EXEC_ARGS=${EXEC_ARGS//--benchmark }
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
            echo "** Invalid Precision for Inference: ${PRECISION} **"
            exit 1
        ;;
    esac

    if [ "${WEIGHT_SHARING}" == "True" ]; then
        LAUNCH_ARGS=${LAUNCH_ARGS//--ncore_per_instance=${CORES_PER_INSTANCE} --ninstances=${INSTANCE_NUMBER}/--ncore_per_instance=${cores_per_numa} --ninstances=${numa_nodes}}
        EXEC_ARGS+=" --use_share_weight --total_cores=${cores_per_numa} --cores_per_instance=${CORES_PER_INSTANCE}"
    fi

    echo "command: python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}"
    python ${LAUNCH_ARGS} ${EVAL_SCRIPT} ${EXEC_ARGS}
fi
if [ "${FUNCTION}" == "training" ]; then
    EXEC_ARGS="--benchmark --input_dir=${TRAIN_DATA_DIR} --eval_dir=${TRAIN_EVAL_DIR} --model_type=bert --output_dir=model_save --dense_seq_output \
               --model_name_or_path=${MODEL_DIR} --learning_rate=3.5e-4 --opt_lamb_beta_1=0.9 --opt_lamb_beta_2=0.999 --warmup_proportion=0.0 \
               --warmup_steps=${WARMUP_STEPS} --start_warmup_step=0 --max_steps=${STEPS} --phase2 --max_predictions_per_seq=76 --do_train --skip_checkpoint \
               --train_mlm_accuracy_window_size=0 --target_mlm_accuracy=0.720 --weight_decay_rate=0.01 --max_samples_termination=4500000 \
               --eval_iter_start_samples=150000 --eval_iter_samples=150000 --eval_batch_size=16 --gradient_accumulation_steps=1 --log_freq=0 \
               --train_batch_size=${BATCH_SIZE}"

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
        * )
            echo "** Invalid Precision for Training: ${PRECISION} **"
            exit 1
        ;;
    esac

    if [ "${DISTRIBUTED}" == "True" ]; then
        source /root/anaconda3/lib/python3.10/site-packages/oneccl_bindings_for_pytorch/env/setvars.sh
        LAUNCH_ARGS=${LAUNCH_ARGS//--enable_jemalloc/--enable_tcmalloc}
        LAUNCH_ARGS=${LAUNCH_ARGS//--ninstances=${INSTANCE_NUMBER}/--nnodes=${NNODES}}
        LAUNCH_ARGS=${LAUNCH_ARGS//--ncore_per_instance=${CORES_PER_INSTANCE}/--nproc_per_node=${INSTANCE_NUMBER}}
        LAUNCH_ARGS+=" --ccl_worker_count=${CCL_WORKER_COUNT} --logical_core_for_ccl"
        LAUNCH_ARGS+=" --skip_cross_node_cores --distributed --master_addr=bertlarge-pytorch-xeon-public-benchmark-0.headless-svc"
        if [ $NNODES -gt 1 ]; then
            hostname=$(cat /etc/hostname)
            echo $POD_IP > hostfile
            service ssh start
            if [ "${hostname}" == "bertlarge-pytorch-xeon-public-benchmark-0" ]; then
                join_worker() {
                    RET=1
                    while [ $RET -ne 0 ]; do
                        echo "waiting worker-$1 to join..."
                        sleep 10
                        sshpass -p s ssh-copy-id -i ~/.ssh/id_rsa.pub root@bertlarge-pytorch-xeon-public-benchmark-$1.headless-svc > /dev/null 2>&1
                        RET=$?
                    done
                    ssh root@bertlarge-pytorch-xeon-public-benchmark-$1.headless-svc cat /home/workspace/hostfile | xargs echo >> hostfile
                    echo "worker-$1 joined successfully"
                }
                for node in $(seq 1 $((NNODES-1))); do
                    join_worker $node &
                done
                wait
            else
                exit 0
            fi
        fi
    else
        LAUNCH_ARGS=${LAUNCH_ARGS//--ninstances=${INSTANCE_NUMBER}/--ninstances=1}
    fi

    echo "command: python ${LAUNCH_ARGS} ${TRAIN_SCRIPT} ${EXEC_ARGS}"
    python ${LAUNCH_ARGS} ${TRAIN_SCRIPT} ${EXEC_ARGS}
fi
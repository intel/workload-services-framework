#! /bin/bash

jemalloc_topology="maskrcnn bert_large distilbert_base"
weight_sharing_topology="resnet50_v15 resnext101_32x16d bert_large distilbert_base"

# pt common args
function pt_common_args() {

    ARGS="python -m intel_extension_for_pytorch.cpu.launch \
          --log_path=${OUTPUT_DIR} \
          --log_file_prefix=${TOPOLOGY}_log_${FUNCTION}_${MODE}_${PRECISION}_bs_${BATCH_SIZE}_${DATA_TYPE}"
    
    if [[ "$jemalloc_topology" =~ "$TOPOLOGY" ]]; then
        ARGS+=" --enable_jemalloc"
    else
        ARGS+=" --use_default_allocator"
    fi

    if [ "$FUNCTION" == "inference" ] ; then
        if [ "$MODE" == "latency" ]; then
            if [[ "$weight_sharing_topology" =~ "$TOPOLOGY" ]] && [[ "$WEIGHT_SHARING" == "True" ]]; then
                ARGS+=" --ninstances ${NUMA_NODES}"
            elif [ "$CORES_PER_INSTANCE" != "-1" ]; then
                ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE}"
            else
                ARGS+=" --latency_mode"
            fi
        elif [ "$MODE" == "throughput" ]; then
            if [ "$CORES_PER_INSTANCE" != "-1" ]; then
                ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE} \
                        --ninstances ${NUMA_NODES}"
            else
                ARGS+=" --throughput_mode"
            fi
        elif [ "$MODE" == "accuracy" ]; then
            if [ "$CORES_PER_INSTANCE" != "-1" ]; then
                ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE} \
                        --ninstances 1"
            else
                ARGS+=" --node_id 0"
            fi
        fi
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" --node_id 0"
        if [ "$CORES_PER_INSTANCE" != "-1" ]; then
            ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE} \
                    --ninstances 1"
        fi
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi
    echo $ARGS
}

# resnet50v1_5 pt args
function resnet50v1_5_pt_args() {

    ARGS=$(pt_common_args)
    ARGS+=" ${BENCHMARK_DIR}/models/image_recognition/pytorch/common/main.py"
    ARGS+=" -a resnet50 \
            -b ${BATCH_SIZE} \
            -j 0 \
            --ipex \
            --configure-dir ${MODEL_DIR}/models/image_recognition/pytorch/common/resnet50_configure_sym.json"

    if [[ $PRECISION =~ "int8" ]]; then
        ARGS+=" --int8"
    elif [[ $PRECISION == "amx_bfloat16" ]]; then
        ARGS+=" --bf16 --jit"
    elif [[ $PRECISION =~ "bf32" ]]; then
        ARGS+=" --bf32 --jit"
    elif [[ $PRECISION =~ "fp32" ]]; then
        ARGS+=" --jit"
    else
        echo "Not support precision ${PRECISION}"
        exit 1
    fi

    # Use real, dummy data
    if [ "$DATA_TYPE" == "dummy" ]; then
        ARGS+=" --dummy"
    fi

    # Inference training args
    if [ "$FUNCTION" == "inference" ] ; then
        ARGS+=" -e \
                --steps ${STEPS}"
        if [ "$MODE" == "accuracy" ]; then
            ARGS+=" --pretrained"
        else
            ARGS+=" --seed 2020"
        fi
        if [ "$FUNCTION" == "latency" ] && [ "$WEIGHT_SHARING" == "True" ]; then
            ARGS+=" --weight-sharing"
            if [ "$CORES_PER_INSTANCE" != "-1" ]; then
                NUMBER_INSTANCE=$(expr ${CORES_PER_NUMA} \/ ${CORES_PER_INSTANCE})
                ARGS+=" --number-instance ${NUMBER_INSTANCE}"
            else
                NUMBER_INSTANCE=$(expr ${CORES_PER_NUMA} \/ 4)
                ARGS+=" --number-instance ${NUMBER_INSTANCE}"
            fi
        fi
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" --seed 2020 \
                --epochs ${TRAINING_EPOCHS} \
                --train-no-eval \
                -w 50"
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi
    echo $ARGS
}

# bert_large pt args
function bert_large_pt_args() {

    ARGS=$(pt_common_args)
    if [ "$FUNCTION" == "inference" ] ; then
        ARGS+=" ${BENCHMARK_DIR}/quickstart/language_modeling/pytorch/bert_large/inference/cpu/transformers/examples/question-answering/run_squad.py"
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" ${BENCHMARK_DIR}/models/language_modeling/pytorch/bert_large/training/run_pretrain_mlperf.py"
    ARGS+=" --model_type bert"

    if [[ $PRECISION == "amx_int8" ]]; then
        ARGS+=" --int8"
    elif [[ $PRECISION == "amx_bfloat16" ]]; then
        ARGS+=" --bf16"
    elif [[ $PRECISION == "avx_int8" ]]; then
        ARGS+=" --int8 --int8_fp32"
    fi

    # Inference training args
    if [ "$FUNCTION" == "inference" ] ; then
        ARGS+=" --per_gpu_eval_batch_size ${BATCH_SIZE} \
                --perf_run_iters ${STEPS} \
                --model_name_or_path ${DATASET_DIR}/bert/enwiki-20200101/bert_large_mlperf_checkpoint/checkpoint \
                --tokenizer_name bert-large-uncased-whole-word-masking-finetuned-squad \
                --do_eval \
                --do_lower_case \
                --predict_file ${DATASET_DIR}/bert/enwiki-20200101/bert_large_mlperf_checkpoint/checkpoint/dev-v1.1.json \
                --learning_rate 3e-5 \
                --num_train_epochs 2.0 \
                --max_seq_length ${SEQ_LENGTH} \
                --doc_stride 128 \
                --output_dir ${OUTPUT_DIR} \
                --perf_begin_iter 15 \
                --use_jit \
                --int8_config ${MODEL_DIR}/quickstart/language_modeling/pytorch/bert_large/inference/cpu/configure.json"
        if [ "$MODE" == "throughput" ]; then
            ARGS+=" --benchmark \
                    --perf_begin_iter 15"
        elif [ "$MODE" == "latency" ]; then
            ARGS+=" --benchmark \
                    --perf_begin_iter 20"
            if [ "$WEIGHT_SHARING" == "True" ]; then
                ARGS+=" --use_share_weight \
                        --total_cores ${CORES_PER_NUMA}"
                if [ "$CORES_PER_INSTANCE" != "-1" ]; then
                    ARGS+=" --cores_per_instance ${CORES_PER_INSTANCE}"
                else
                    ARGS+=" --cores_per_instance ${NUMA_NODES}"
                fi
            fi
        fi
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" --train_batch_size ${BATCH_SIZE} \
                --benchmark \
                --input_dir ${DATASET_DIR}/bert/bert_results4_dataset/2048_shards_uncompressed_${SEQ_LENGTH}/ \
                --eval_dir ${DATASET_DIR}/bert/bert_results4_dataset/eval_set_uncompressed/ \
                --output_dir model_save \
                --dense_seq_output \
                --config_name ${DATASET_DIR}/bert/enwiki-20200101/bert_large_mlperf_checkpoint/checkpoint/bert_config.json \
                --learning_rate=3.5e-4 \
                --opt_lamb_beta_1=0.9 \
                --opt_lamb_beta_2=0.999 \
                --warmup_proportion=0.0 \
                --warmup_steps=0.0 \
                --start_warmup_step=0 \
                --max_steps=13700 \
                --max_predictions_per_seq=76 \
                --do_train \
                --skip_checkpoint \
                --train_mlm_accuracy_window_size=0 \
                --target_mlm_accuracy=0.720 \
                --weight_decay_rate=0.01 \
                --max_samples_termination=4500000 \
                --eval_iter_start_samples=150000 \
                --eval_iter_samples=150000 \
                --eval_batch_size=16 \
                --gradient_accumulation_steps=1 \
                --log_freq=0"
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi
    echo $ARGS
}


# dlrm pt args
function dlrm_pt_args() {

    ARGS=$(pt_common_args)
    ARGS+=" ${BENCHMARK_DIR}/models/recommendation/pytorch/dlrm/product/dlrm_s_pytorch.py"
    ARGS+=" --mini-batch-size ${BATCH_SIZE} \
            --num-batches ${STEPS} \
            --raw-data-file=${DATASET_DIR}/dlrm/input/day \
            --processed-data-file=${DATASET_DIR}/dlrm/input/terabyte_processed.npz \
            --data-set=terabyte \
            --memory-map \
            --mlperf-bin-loader \
            --round-targets=True \
            --learning-rate=1.0 \
            --arch-mlp-bot=13-512-256-128 \
            --arch-mlp-top=1024-1024-512-256-1 \
            --arch-sparse-feature-size=128 \
            --max-ind-range=40000000 \
            --ipex-interaction \
            --numpy-rand-seed=727 \
            --print-time"

    if [[ $PRECISION =~ "int8" ]]; then
        ARGS+=" --int8 \
                --int8-configure ${BENCHMARK_DIR}/models/recommendation/pytorch/dlrm/product/int8_configure.json"
    elif [[ $PRECISION == "amx_bfloat16" ]]; then
        ARGS+=" --bf16"
    fi

    # Inference training args
    if [ "$FUNCTION" == "inference" ] ; then
        ARGS+=" --inference-only \
                --print-freq=10"
        if [ "$MODE" == "accuracy" ]; then
            ARGS+=" --test-mini-batch-size=16384 \
                    --test-freq=2048 \
                    --print-auc \
                    --load-model=${DATASET_DIR}/dlrm/input/terabyte_mlperf_official.pt"
        elif [ "$MODE" == "throughput" ]; then
            if [ "$WEIGHT_SHARING" == "True" ]; then
                if [ "$CORES_PER_INSTANCE" != "-1" ]; then
                    ARGS+=" --share-weight-instance=${CORES_PER_INSTANCE}"
                else
                    ARGS+=" --share-weight-instance=${CORES_PER_NUMA}"
                fi
            fi
        fi
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" --print-auc \
                --mlperf-auc-threshold=0.8025 \
                --print-freq=100 \
                --print-time \
                --test-mini-batch-size=16384 \
                --ipex-merged-emb"
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi
    echo $ARGS
}

# distilbert pt args
function distilbert_pt_args() {

    ARGS=$(pt_common_args)
    ARGS+=" ${BENCHMARK_DIR}/quickstart/language_modeling/pytorch/distilbert_base/inference/cpu/transformers/examples/pytorch/text-classification/run_glue.py"
    ARGS+=" --use_ipex \
            --train_file ${DATASET_DIR}/train \
            --validation_file ${DATASET_DIR}/validation \
            --jit_mode \
            --model_name_or_path ${BENCHMARK_DIR}/distilbert-base-uncased-finetuned-sst-2-english \
            --do_eval \
            --max_seq_length ${MAX_SEQ_LENGTH} \
            --output_dir ${OUTPUT_DIR}"

    if [ $PRECISION == "amx_int8" ]; then
        ARGS+=" --int8 \
                --mix_bf16 \
                --int8-config ${BENCHMARK_DIR}/quickstart/language_modeling/pytorch/distilbert_base/inference/cpu/configure.json"
    elif [ $PRECISION == "amx_bfloat16" ]; then
        ARGS+=" --mix_bf16"
    elif [ $PRECISION == "amx_bfloat32" ]; then
        ARGS+=" --bf32 \
                --auto_kernel_selection"
    elif [ $PRECISION == "avx_int8" ]; then
        ARGS+=" --int8 \
                --int8-config ${BENCHMARK_DIR}/quickstart/language_modeling/pytorch/distilbert_base/inference/cpu/configure.json"
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
                if [ "$CORES_PER_INSTANCE" != "-1" ]; then
                    ARGS+=" --cores_per_instance ${CORES_PER_INSTANCE}"
                else
                    ARGS+=" --cores_per_instance ${NUMA_NODES}"
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
    echo $ARGS
}

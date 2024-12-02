#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

SRC=$(echo $(grep "SRC" $(find . -name benchmark*.log | head -1)) | cut -d ":" -f 2)

# Set all Keys
KEY_WL_CONFIGURATION=(
workload_name    base_model_name    recipe_type    framework    framework_version
hardware    task    model_name    model_size    model_source
fu    mode    precision    data_type    batch_size    inst_num
cores_per_instance    input_tokens    output_tokens    ds_tp    steps
beam    seq_length accuracy
)

KEY_APP_CONFIGURATION=(
scenario    serving_stack    model_workers    request_per_worker
)

KEY_METRICS=(
total_throughput    mean_latency    max_latency    min_latency
p50_latency    p90_latency    p95_latency    p99_latency    p999_latency
ttt    samples    compute_utilization    memory_utilization    flops
model_quality_metric_name    model_quality_value    cost_per_million_inferences
accuracy1
)

KEY_LIST=( "${KEY_WL_CONFIGURATION[@]}" "${KEY_APP_CONFIGURATION[@]}" "${KEY_METRICS[@]}")

function gen_all_kv_pare(){
    for key in ${KEY_LIST[@]}; do
        cmdline+="-v $key=${!key} "
    done
    echo ${cmdline}
}

# step 1: Init all VARs with value "-1"
for key in ${KEY_LIST[@]};do
    declare ${key}="-1"
done

# step 2: Get common value from benchmark*.log
read framework framework_version mode recipe_type <<< $(awk '
    /^FRAMEWORK:/{ framework=$NF }
    /^Torch_Version:/{ framework_version=$NF }
    /^MODE: / { mode=$NF }
    /^RECIPE_TYPE:/ { recipe_type=$NF }
    END{ print framework" "framework_version" "mode" "recipe_type" "}
    ' $(find . -name benchmark*.log | head -1) 2>/dev/null || true
)

# step 3: Set common values
workload_name="DLRMv2-PyTorch-Dev"
model_name="MLPerf/DLRMv2"
model_source="facebook"
dataset="criteo"

# step 4: Set special values for different SRC
if [ "${SRC}" == " paiv" ]; then
# condition 1: workload src is from paiv
    declare override_keys_1=(
        precision fu data_type batch_size steps
        cores_per_instance inst_num total_throughput 
        mean_latency accuracy1
    )
    read ${override_keys_1[@]} <<< $(awk -F ', |: |; ' '
    /precision/ { precision=$NF }
    /function/ { fu=$NF }
    /data_type/ {data_type=$NF }
    /batch_size/ { batch_size=$NF }
    /- accuracy:/ { 
        acc = $2
        if( acc != "")
            accuracy1=acc
        else
            accuracy1="-1"
     }
    /steps/ { steps=$NF }
    /cores_per_instance/ { cores_per_instance=$NF }
    /inst_count/ { inst_num=$NF }
    /- throughput:/ {
        throughput_val = $2
        if( throughput_val != "")
            total_throughput=throughput_val
        else
            total_throughput="-1"
    }
    /- latency:/ {
        latency_val = $2
        if( latency_val != "")
            mean_latency=latency_val
        else
            mean_latency="-1"
    }

    END{
        printf("%s ", precision)
        printf("%s ", fu)
        printf("%s ", data_type)
        printf("%s ", batch_size)
        printf("%s ", steps)
        printf("%s ", cores_per_instance)
        printf("%s ", inst_num)
        printf("%s ", total_throughput)
        printf("%s ", mean_latency)
        printf("%s ", accuracy1)
    }
    ' $(find . -name benchmark*.log | head -1) 2>/dev/null || true)
else
# condition 2: workload src is from wsf
    declare override_keys_2=(
        fu batch_size steps precision cores_per_instance inst_num data_type
        p50_latency p99_latency mean_latency total_throughput
        accuracy1
    )
    read ${override_keys_2[@]} <<< $(awk -F ', |: |; |=' '
    BEGIN{
        fu=-1
        inst_num=0
        precision=-1
        data_type=-1
        p50_latency=0
        p99_latency=0
        mean_latency=0
        total_throughput=0
        batch_size=0
    }
    /^FUNCTION: /{ fu=$NF }
    /^BATCH_SIZE: /{ batch_size=$NF }
    /^STEPS/ { steps=$NF }
    /^PRECISION/ { precision=$NF }
    /^DATA_TYPE/ { data_type=$NF }
    /OMP_NUM_THREADS/ { cores_per_instance=$NF }
    /Throughput:/ {
        inst_num += 1
        throughtput_of_inst = $NF
        total_throughput += throughtput_of_inst
        mean_latency += (batch_size / throughtput_of_inst)
    }
    /^P50/ {
        split($1, tmp_str, " ")
        if ( tmp_str[3] == 0) {
            p50_latency=-1
        }
        else {
            p50_latency += tmp_str[3] / 1000
        }
    }
    /^P99/ {
        split($1, tmp_str, " ")
        if ( tmp_str[3] == 0) {
            p50_latency=-1
        }
        else {
            p99_latency += tmp_str[3] / 1000
        }  
    }
    /eval_accuracy/{
        accuracy1 = $2
    }
    END{
        if (inst_num != 0 ){
            mean_latency = (mean_latency / inst_num) *1000
            p50_latency = p50_latency / inst_num
            p99_latency = p99_latency / inst_num
        } else{
            inst_num=-1
        }
        accuracy1 *=100
    }
    END{
        printf("%s ", fu)
        printf("%s ", batch_size)
        printf("%s ", steps)
        printf("%s ", precision)
        printf("%s ", cores_per_instance)
        printf("%s ", inst_num)
        printf("%s ", data_type)
        printf("%s ", p50_latency)
        printf("%s ", p99_latency)
        printf("%s ", mean_latency)
        printf("%s ", total_throughput)
        printf("%s ", accuracy1)
    }
    ' $(find . -name benchmark*.log | head -1) 2>/dev/null || true)
fi

awk $(gen_all_kv_pare) '
END{
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: "workload_name
    print "##BASE_MODEL_NAME: DLRMv2"
    print "##RECIPE_TYPE: "recipe_type
    print "##FRAMEWORK: "framework
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: Xeon"
    print "##TASK: Recommendation"
    print "##MODEL_NAME: "model_name
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: "model_source
    print "##DATASET: criteo"
    print "##FUNCTION: "fu
    print "##MODE: "mode
    print "##PRECISION: "precision
    print "##DATA_TYPE: "data_type
    print "##BATCH_SIZE: "batch_size
    print "##INSTANCE_NUMBER: "inst_num
    print "##CORES_PER_INSTANCE: "cores_per_instance
    print "##INPUT_TOKENS: "input_tokens
    print "##OUTPUT_TOKENS: "output_tokens
    print "##DS_TP: "ds_tp
    print "##STEPS: "steps
    print "##BEAM: "beam
    print "##SEQ_LENGTH: "seq_length

    print "\n#================================================"
    print "#Application Configuration"
    print "#================================================"
    print "##SCENARIO: "scenario
    print "##SERVING_STACK: "serving_stack
    print "##MODEL_WORKERS: "model_workers
    print "##REQUEST_PER_WORKER: "request_per_worker

    print "\n#================================================"
    print "#Metrics"
    print "#================================================"
    print "Throughput (samples/sec): "total_throughput
    print "Average Latency (ms): "mean_latency
    print "Max Latency (ms): "max_latency
    print "Min Latency (ms): "min_latency
    print "P50 Latency (ms): "p50_latency
    print "P90 Latency (ms): "p90_latency
    print "P95 Latency (ms): "p95_latency
    print "P99 Latency (ms): "p99_latency
    print "P999 Latency (ms): "p999_latency
    print "TTT (ms): "ttt
    print "Samples: "samples
    print "Compute Utilization: "compute_utilization
    print "Memory Utilization: "memory_utilization
    print "FLOPs: "flops
    print "Model Quality Metric Name: "model_quality_metric_name
    print "Model Quality Value: "model_quality_value
    print "Cost Per Million Inference: "cost_per_million_inferences

    print "\n#================================================"
    print "#Key KPI"
    print "#================================================"
    if ( mode == "accuracy" ){
        print "*""Accuracy(%):",accuracy1
    }
    else if ( mode == "throughput" ){
        print "*""Throughput (samples/sec):",total_throughput
    }
    else {
        print "*""Latency (ms): ",mean_latency
    }
}' /dev/null || true

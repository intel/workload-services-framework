#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# awk -F ', |: |; ' '
awk -F "[,= ]" '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.\[\]]+ *(.*)/, "\\1", 1, value);
    value=gensub(/^([0-9+-.]+).*/, "\\1", 1, value);
    key=gensub(/(.*): *$/, "\\1", 1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
function getvalue(value) {
    if (value=="'\'''\''") {
        value="-1"
    }
    return value;
}
BEGIN {
    framework="-1"
    pytorch="unknown"
    model_name="BERTLarge"
    model_source="IntelModelZoo"
    scenario="Offline"

    fu="-1"
    mode="-1"
    precision="-1"
    data_type="-1"
    batch_size="-1"
    steps="-1"
    test_time="-1"
    cores_per_instance="-1"
    inst_num="-1"
    train_epoch="-1"
    
    serving_stack="-1"
    model_workers="-1"
    request_per_worker="-1"
    
    accuracy="-1"
    average_throughput="-1"
    max_latency="-1"
    min_latency="-1"
    mean_latency="0"
    p50_latency="-1"
    p90_latency="-1"
    p95_latency="-1"
    p99_latency="-1"
    p999_latency="-1"
    ttt="-1"
    samples="-1"
    compute_utilization="-1"
    memory_utilization="-1"
    flops="-1"
    model_quality_metric_name="-1"
    model_quality_value="-1"
    cost_per_million_inferences="-1"
    total_throughput="0"
    la_sum_inf=0
    i=0
    j=0
    print_not_all_instances=0
    input_tokens="-1"
    output_tokens="-1"
    beam="-1"
    seq_length="-1"
    throughput=0
    
}
/^Torch_Version:/ {
   pytorch_version=$2
}

/^MODE/ {
   mode=$2
}
/^TOPOLOGY/{
   model_name=$2
}
/^FUNCTION/ {
   fu=$2
}

/^PLATFORM/{
   PLATFORM=$2
}

/^PRECISION/ {
   precision=$2
}

/^BATCH_SIZE/ {
   batch_size=$2
}
/^STEPS/ {
   steps=$2
}
/^DATA_TYPE/ {
   data_type=$2
}
/^CORES_PER_INSTANCE/ {
   cores_per_instance=$2
}
/^Throughput:/ {
    throughput=$2
    if (throughput > 0){
        total_throughput += throughput
        i+=1
    }
}
/^P99 Latency/ {
    p99_latency=$3
    
}

END {
    
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: BERTLarge-PyTorch-ARM"
    print "##BASE_MODEL_NAME: BERTLarge"
    print "##RECIPE_TYPE: Dev"
    print "##FRAMEWORK: pytorch"
    print "##PyTorch_VERSION: "pytorch_version
    print "##HARDWARE: ARM"
    #check
    print "##FUNCTION: "fu
    #check
    print "##MODE: "mode
    print "##PRECISION: "precision
    #check
    print "##DATA_TYPE: "data_type
    print "##BATCH_SIZE: "batch_size
    print "##STEPS: "steps
    print "##CORES_PER_INSTANCE: "cores_per_instance
    print "##Instance Number: "i
    
    print "##INPUT_TOKENS: "input_tokens
    print "##OUTPUT_TOKENS: "output_tokens
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
    average_throughput="-1"

    # is i the instance number
    if ( i != 0 ){
        average_throughput=total_throughput/i
    }
    print "Total Throughput (samples/sec): "total_throughput
    print "Average Latency (ms): "mean_latency
    print "Max Latency (ms): "max_latency
    print "Min Latency (ms): "min_latency
    print "P50 Latency (ms): "p50_latency
    print "P90 Latency (ms): "p90_latency
    print "P95 Latency (ms): "p95_latency
    print "P99 Latency (ms): "p99_latency
    print "P999 Latency (ms): "p999_latency
    print "TTT (s): "ttt
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
    print kvformat("*""Throughput",total_throughput/i "samples/sec")
    print kvformat("Total Throughput",total_throughput "samples/sec")
    if ( print_not_all_instances == 1 ){
        print "#INVALID RESULT: Some instances were killed during execution! See README.md for more."
    }
}
' */benchmark*.log 2>/dev/null || true
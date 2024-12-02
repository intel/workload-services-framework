#! /bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -F ', |: |; ' '
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
    model_name="ResNet50"
    model_size="-1"
    model_source="IntelModelZoo"
    dataset="ImageNet" 
    scenario="Offline"
    fu="-1"
    mode="-1"
    precision="-1"
    data_type="-1"
    batch_size="-1"
    steps="-1"
    test_time="-1"
    cores_per_inst="-1"
    inst_num="0"
    input_tokens="-1"
    output_tokens="-1"
    beam="-1"
    seq_length="-1"
    
    serving_stack="-1"
    model_workers="-1"
    request_per_worker="-1"
    
    total_throughput="-1"
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

    first_token_average_latency="-1"
    second_token_average_latency="-1"
    input_tokens="-1"
    output_tokens="-1"
    seq_length="-1"
    beam="-1"
    ds_tp="-1"
    src="-1"
    recipe_type="-1"
}
/MODE/{
    mode=$2
}
/^PLATFORM/{
    PLATFORM=$2
}
/^STEPS/{
    steps=$2
}
/^PRECISION/{
    precision=$2
}
/^FUNCTION/{
    fu=$2
}
/^TOPOLOGY/{
    model_name=$2
}
/^DATA_TYPE/{
    data_type=$2
}
/^BATCH_SIZE/{
    batch_size=$2
}
/^CORES_PER_INSTANCE/{
    cores_per_inst=$2
}
/Throughput/{
    mean_latency+=(batch_size/$2)
    total_throughput+=$2
    inst_num+=1
}
/Training throughput/{
    total_throughput+=$2
    inst_num+=1
}
/Accuracy/{
    accuracy=$2
}
/^Torch_Version:/{ framework_version=$2 }
/^FRAMEWORK:/{ framework=$2 }
/^RECIPE_TYPE:/{ recipe_type=$2 }
END {
    print "#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: ResNet50-PyTorch-Xeon-Public"
    print "##BASE_MODEL_NAME: ResNet50"
    print "##RECIPE_TYPE: "recipe_type
    print "##FRAMEWORK: "framework
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: xeon"
    print "##TASK: Image Classification"
    print "##MODEL_NAME: ResNet50v1.5"
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: "model_source
    print "##DATASET: "dataset
    print "##FUNCTION: "fu
    print "##MODE: "mode
    if ( precision == "amx_bfloat16" && PLATFORM == "GENOA") {
        precision="avx_bfloat16"
    }
    print "##PRECISION: "precision
    print "##DATA_TYPE: "data_type
    print "##BATCH_SIZE: "batch_size
    print "##INSTANCE_NUMBER: "inst_num
    print "##CORES_PER_INSTANCE: "cores_per_inst
    print "##INPUT_TOKENS: "input_tokens
    print "##OUTPUT_TOKENS: "output_tokens
    print "##STEPS: "steps
    print "##BEAM: "beam
    print "##SEQ_LENGTH: "seq_length
    print "#================================================"
    print "#Application Configuration"
    print "#================================================"
    print "##SCENARIO: "scenario
    print "##SERVING_STACK: "serving_stack
    print "##MODEL_WORKERS: "model_workers
    print "##REQUEST_PER_WORKER: "request_per_worker
    print "#================================================"
    print "#Metrics"
    print "#================================================"
    print kvformat("Average Throughput", sprintf("%.2f", total_throughput/inst_num) "img/s")
    print "Average Latency (sec): "mean_latency/inst_num
    print "Max Latency (sec): "max_latency
    print "Min Latency (sec): "min_latency
    print "P50 Latency (sec): "p50_latency
    print "P90 Latency (sec): "p90_latency
    print "P95 Latency (sec): "p95_latency
    print "P99 Latency (sec): "p99_latency
    print "P999 Latency (sec): "p999_latency
    print "Samples: "samples
    print "Compute Utilization: "compute_utilization
    print "Memory Utilization: "memory_utilization
    print "FLOPs: "flops
    print "Model Quality Metric Name: "model_quality_metric_name
    print "Model Quality Value: "model_quality_value
    print "Cost Per Million Inference: "cost_per_million_inferences
    print "#================================================"
    print "#Key KPI"
    print "#================================================"
    if (mode == "throughput") {
        print "*Throughput (img/s): "total_throughput
    }
    else if (mode == "latency") {
        print "*Latency (sec): "mean_latency/inst_num
    }
    else {
        print "*Accuracy (%): "accuracy
    }
}
' */benchmark_*.log 2>/dev/null || true

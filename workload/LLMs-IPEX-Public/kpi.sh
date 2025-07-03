#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -F '\\||, |: |; |=' '
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
    workload_name="LLMs-IPEX-Public"
    framework="PyTorch+IPEX"
    framework_version="-1"
    model_name="-1"
    model_size="-1"
    model_source="HuggingFace"
    dataset="prompt"
    fu="inference"
    mode="-1"
    precision="-1"
    data_type="real"
    batch_size="-1"
    steps="-1"
    test_time="-1"
    cores_per_instance="-1"
    inst_num="1"

    serving_stack="-1"
    model_workers="-1"
    request_per_worker="-1"

    total_throughput="-1"
    throughput_per_token="-1"
    accuracy="-1"
    average_throughput="-1"
    max_latency="-1"
    min_latency="-1"
    mean_latency="-1"
    p50_latency="-1"
    p90_latency="-1"
    p95_latency="-1"
    p99_latency="-1"
    p999_latency="-1"
    p90="0"
    p99="0"
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
}
/^MODEL_NAME:/{ model_name=$2 }
/^STEPS:/{ steps=$2 }
/^MODE:/{ mode=$2 }
/BATCH_SIZE:/{ batch_size=$2 }
/CORES_PER_INSTANCE/{ cores_per_instance=$2 }
/PRECISION:/{ precision=$2 }
/^INPUT_TOKENS:/{ input_tokens=$2 }
/^OUTPUT_TOKENS:/{ output_tokens=$2 }
/^BEAM:/{ beam=$2 }
/^SRC:/{ src=$2 }
/^BASE_MODEL_NAME:/{ base_model_name=$2 }
/^MODEL_SIZE:/{ model_size=$2 }
/Inference latency:/{ 
    split($2, tmp_str, " ")
    mean_latency=tmp_str[1]/1000
}
/\|acc/{
    accuracy=$5
}
/First token average latency:/{
    split($2, tmp_str, " ")
    first_token_average_latency=tmp_str[1]/1000
}
/Average 2... latency:/{
    split($2, tmp_str, " ")
    second_token_average_latency=tmp_str[1]/1000
    total_throughput=batch_size/second_token_average_latency
}
/^P50/{ p50_latency+= ($2/1000) }
/^P90/{ 
    p90_latency="0"
    p90_latency+= ($2/1000)
    p90+=1
}
/^P95/{ p95_latency+=($2/1000) }
/^P99/{
    p99_latency="0"
    p99_latency+=($2/1000)
    p99+=1
    }
/^P99.9/{ p999_latency=($2/1000) }
/torch.version:/{
    framework_version=$2
}
/^DS_TP:/{ ds_tp=$2 }
END{
    if ( output_tokens == "1" ){
        first_token_average_latency=mean_latency
        total_throughput=batch_size/mean_latency
        second_token_average_latency="-1"
    }
}
END {
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: "workload_name
    print "##BASE_MODEL_NAME: "base_model_name
    print "##RECIPE_TYPE: Public"
    print "##FRAMEWORK: "framework
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: Xeon"
    print "##TASK: Text Generation"
    print "##MODEL_NAME: "model_name
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: "model_source
    print "##DATASET: "dataset
    print "##FUNCTION: "fu
    print "##MODE: "mode
    print "##PRECISION: "precision
    print "##DATA_TYPE: "data_type
    print "##BATCH_SIZE: "batch_size
    print "##INSTANCE_NUMBER: "inst_num
    print "##CORES_PER_INSTANCE: "cores_per_instance
    print "##STEPS: "steps
    print "##INPUT_TOKENS: "input_tokens
    print "##OUTPUT_TOKENS: "output_tokens
    print "##DS_TP: "ds_tp
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
    print "Throughput (tokens/sec): "total_throughput 
    print "Average Latency (sec): "second_token_average_latency
    print "1st token latency (sec): "first_token_average_latency
    print "2nd+ tokens average latency (sec): "second_token_average_latency
    print "Max Latency (sec): "max_latency
    print "Min Latency (sec): "min_latency
    print "P50 Latency (sec): "p50_latency
    print "P90 Latency (sec): "p90_latency
    print "P95 Latency (sec): "p95_latency
    print "P99 Latency (sec): "p99_latency
    print "P999 Latency (sec): "p999_latency
    print "TTT (sec): "ttt
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
        print "*""Accuracy(%):",accuracy * 100
    }
    else if ( mode == "throughput" ){
        print "*""Throughput (tokens/sec):",total_throughput
    }
    else {
        print "*""2nd+ tokens average latency (sec): ",second_token_average_latency
    }
}
' $(find . -name "benchmark*.log")  || true
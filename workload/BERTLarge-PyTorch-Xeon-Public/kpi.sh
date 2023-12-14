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
    framework="PyTorch"
    model_name="-1"
    model_size="-1"
    model_source="IntelModelZoo"
    dataset="SQuAD_v1.1"
    scenario="Offline"

    fu="-1"
    mode="-1"
    precision="-1"
    data_type="-1"
    batch_size="-1"
    steps="-1"
    test_time="-1"
    cores_per_inst="-1"
    inst_num="-1"
    
    serving_stack="-1"
    model_workers="-1"
    request_per_worker="-1"
    
    total_throughput=0
    real_inst=0
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
    ttt="-1"
    samples="-1"
    compute_utilization="-1"
    memory_utilization="-1"
    flops="-1"
    model_quality_metric_name="-1"
    model_quality_value="-1"
    cost_per_million_inferences="-1"
    input_tokens="-1"
    output_tokens="-1"
    beam="-1"
    seq_length="-1"
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
/^DATA_TYPE/{
    data_type=$2
}
/^BATCH_SIZE/{
    batch_size=$2
}
/^CORES_PER_INSTANCE/{
    cores_per_inst=$2
}
/^INSTANCE_NUMBER/{
    inst_num=$2
}
/Throughput/{
    real_inst+=1
    total_throughput+=$NF
}
/Results/{
    accuracy=$3
}
/^Torch_Version:/{ 
    framework_version=$2 
}
/^Seq_Length:/{ 
    seq_length=$2 
}
END {
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: BERTLarge-PyTorch-Public"
    print "##BASE_MODEL_NAME: BERT-Large"
    print "##RECIPE_TYPE: Public"
    print "##FRAMEWORK: PyTorch"
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: xeon"
    print "##TASK: Question Answering"
    print "##MODEL_NAME: bert-large-uncased-whole-word-masking-finetuned-squad"
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
    if (framework == "OpenVINO") {
        print "##TEST_TIME (s): "test_time
    }
    else {
        print "##STEPS: "steps
    }
    print "##INSTANCE_NUMBER: "inst_num
    print "##REAL_INSTANCE_NUMBER: "real_inst
    print "##CORES_PER_INSTANCE: "cores_per_inst
    print "##SEQ_LENGTH: "seq_length
    print "##INPUT_TOKENS: "input_tokens
    print "##OUTPUT_TOKENS: "output_tokens
    print "##BEAM: "beam
    
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
    print kvformat("Average Throughput", sprintf("%.2f", total_throughput/inst_num) "samples/sec")
    if (mode != "accuracy") {
        mean_latency=1000*inst_num/total_throughput
    }
    print "Average Latency (ms): "mean_latency
    print "Max Latency (ms): "max_latency
    print "Min Latency (ms): "min_latency
    print "P50 Latency (ms): "p50_latency
    print "P90 Latency (ms): "p90_latency
    print "P95 Latency (ms): "p95_latency
    print "P99 Latency (ms): "p99_latency
    print "P999 Latency (ms): "p999_latency
    if (fu == "training") {
        ttt=gensub("\]", "", "g", ttt)
        print kvformat("TTT", sprintf("%.2f", ttt) "s")
    }
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
    if (mode == "throughput") {
        print "*Throughput (samples/sec): "total_throughput
    }
    else if (mode == "latency") {
        print "*Latency (ms): "mean_latency
    }
    else {
        print "*Accuracy (%): "accuracy
    }
}
' */benchmark_*.log 2>/dev/null || true
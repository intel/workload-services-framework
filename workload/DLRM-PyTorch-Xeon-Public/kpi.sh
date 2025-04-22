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
    framework_version="-1"
    model_name="dlrm"
    model_size="-"
    model_source="IntelAI"
    dataset="CriteoTerabyteDataset" 
    scenario="Offline"
    fu="-"
    mode="-"
    precision="-"
    data_type="-"
    batch_size="-"
    steps="-"
    test_time="-"
    cores_per_inst="-"
    inst_num="-"
    train_epoch="-"
    
    serving_stack="-"
    model_workers="-"
    request_per_worker="-"
    
    total_throughput=0
    accuracy="-"
    average_throughput="-"
    max_latency="-"
    min_latency="-"
    mean_latency="-"
    p50_latency="-"
    p90_latency="-"
    p95_latency="-"
    p99_latency="-"
    p999_latency="-"
    ttt="-"
    samples="-"
    compute_utilization="-"
    memory_utilization="-"
    flops="-"
    model_quality_metric_name="-"
    model_quality_value="-"
    cost_per_million_inferences="-"
}
/torch.version:/{framework_version=$2}
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
/^INSTANCE_NUMBER/{
    inst_num=$2
}
/^Throughput/{
    total_throughput+=$2
}
/^Accuracy/{
    accuracy=100*$2
}
END {
    print "#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: DLRM-PyTorch-Public"
    print "##BASE_MODEL_NAME: DLRM"
    print "##RECIPE_TYPE: public"
    print "##FRAMEWORK: PyTorch"
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: xeon"
    print "##TASK: Recommendation"
    print "##MODEL_NAME: MLPerf/DLRM"
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: "model_source
    print "##DATASET: "dataset
    print "##FUNCTION: "fu
    print "##MODE: "mode    
    print "##PRECISION: "precision
    print "##DATA_TYPE: "data_type
    print "##BATCH_SIZE: "batch_size
    print "##STEPS: "steps
    print "##INSTANCE_NUMBER: "inst_num
    print "##CORES_PER_INSTANCE: "cores_per_inst
    if (fu == "training") {
        print "##TRAIN_EPOCH: "train_epoch
    }
    
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
    if (mode == "throughput") {
        print kvformat("Average Throughput", sprintf("%.2f", total_throughput/inst_num) "samples/sec")
    }
    print "Max Latency (ms): "max_latency
    print "Min Latency (ms): "min_latency
    if (mode == "throughput") {
        mean_latency=1000*inst_num/total_throughput
    }
    print "Mean Latency (ms): "mean_latency
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
    print "#================================================"
    print "#Key KPI"
    print "#================================================"
    if (mode == "throughput") {
        printf("*Throughput (samples/sec): %.3f", total_throughput);
    }
    else if (mode == "latency") {
        print "*Latency (ms): "mean_latency
    }
    else {
        print "*Accuracy (%): "accuracy
    }
}
' */benchmark_*.log 2>/dev/null || true

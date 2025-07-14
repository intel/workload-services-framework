#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -F ', |: |; |=' '
BEGIN{
    framework="-1"
    model_name="-1"
    model_size="-1"
    steps="-1"
    recipe_type="-1"
    instance_number="-1"
    cores_per_instance="-1"
    max_latency=-1
    min_latency=-1
    p50_latency=-1
    p90_latency=-1
    p95_latency=-1
    p99_latency=-1
    p999_latency=-1
    input_tokens="-1"
    output_tokens="-1"
    beam="-1"
    ds_tp="-1"
    total_throughput=0
    latency=-1
    accuracy=-1
    inst_num=0
    image_width="-1"
    image_height="-1"
    dnoise_steps="-1"
}
/^BASE_MODEL_NAME: /{ base_model_name=$2 }
/^Framework:/{ framework=$2 }
/^MODEL_NAME:/{ model_name=$2 }
/^STEPS:/{ steps=$2 }
/^CORES_PER_INSTANCE/ { cores_per_instance=$2 }
/torch.version:/{ framework_version=$2 }
/^RECIPE_TYPE:/{ recipe_type=$2 }
/^MODE:/{ mode=$2 }
/^PRECISION:/{ precision=$2 }
/^IMAGE_WIDTH:/{ image_width=$2 }
/^IMAGE_HEIGHT:/{ image_height=$2 }
/^DNOISE_STEPS:/{ dnoise_steps=$2 }
/^Throughput/ {
    total_throughput += $2
    inst_num+=1
}
/^Latency/ {
    Latency+=$2
}
/^FID:/{
    inst_num+=1
    accuracy=$2
}

END{
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: Diffusions-PyTorch-Public"
    print "##BASE_MODEL_NAME: "base_model_name
    print "##RECIPE_TYPE: "recipe_type
    print "##FRAMEWORK: "framework
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: Xeon"
    print "##TASK: text to image"
    print "##MODEL_NAME: "model_name
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: Huggingface"
    if (mode != "accuracy" ){
        print "##DATASET: prompt"
    }
    else {
        print "##DATASET: coco2017"
    }
    print "##FUNCTION: inference"
    print "##MODE: "mode
    print "##PRECISION: "precision
    print "##DATA_TYPE: real"
    print "##BATCH_SIZE: 1"
    print "##INSTANCE_NUMBER: "inst_num
    print "##CORES_PER_INSTANCE: "cores_per_instance
    print "##INPUT_TOKENS: -1"
    print "##OUTPUT_TOKENS: -1"
    print "##DS_TP: -1"
    print "##STEPS: "steps
    print "##BEAM: -1"
    print "##IMAGE_WIDTH: "image_width
    print "##IMAGE_HEIGHT:" image_height
    print "##DNOISE_STEPS: "dnoise_steps

    print "\n#================================================"
    print "#Application Configuration"
    print "#================================================"
    print "##SCENARIO: -1"
    print "##SERVING_STACK: -1"
    print "##MODEL_WORKERS: -1"
    print "##REQUEST_PER_WORKER: -1"

    print "\n#================================================"
    print "#Metrics"
    print "#================================================"
    print "Throughput (img/sec): "total_throughput
    print "Average Latency (sec): "Latency/inst_num
    print "1st token latency (sec): -1"
    print "2nd+ tokens average latency (sec): -1"
    print "Max Latency (sec): "max_latency
    print "Min Latency (sec): "min_latency
    print "P50 Latency (sec): "p50_latency
    print "P90 Latency (sec): "p90_latency
    print "P95 Latency (sec): "p95_latency
    print "P99 Latency (sec): "p99_latency
    print "P999 Latency (sec): "p999_latency
    print "TTT (sec): -1"
    print "Samples: -1"
    print "Compute Utilization: -1"
    print "Memory Utilization: -1"
    print "FLOPs: -1"
    print "Model Quality Metric Name: -1"
    print "Model Quality Value: -1"
    print "Cost Per Million Inference: -1"

    print "\n#================================================"
    print "#Key KPI"
    print "#================================================"
    print mode
    if ( mode == "accuracy" ){
        print "*""Accuracy(FID):",accuracy
    }
    else if ( mode == "throughput" ){
        print "*""Throughput (img/sec):",total_throughput
    }
    else {
        print "*""Latency (sec): ",Latency/inst_num
    }
}
' $(find . -name "benchmark_*.log")  || true

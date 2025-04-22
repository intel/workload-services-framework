#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -F ', |: |; |= |  |' '

function calculatePLatencies(){
    if(mode=="throughput"){
        asort(latency_list)
        latency_count=0
        for(j=0;j<=i;j++){
            if (latency_list[j] != "") {
                latency_list[latency_count] = latency_list[j]
                latency_count=latency_count+1
            }
        }
        p999_index=int(latency_count*0.999 + 0.5)
        p99_index=int(latency_count*0.99 + 0.5)
        p95_index=int(latency_count*0.95 + 0.5)
        p90_index=int(latency_count*0.90 + 0.5)
        p50_index=int(latency_count*0.5 + 0.5)
        p50_latency=latency_list[p50_index-1]
        p90_latency=latency_list[p90_index-1]
        p95_latency=latency_list[p95_index-1]
        p99_latency=latency_list[p99_index-1]
        p999_latency=latency_list[p999_index-1]
    }
}

BEGIN{
    framework="-1"
    model_name="-1"
    model_size="-1"
    steps="-1"
    batch_size="-1"
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
    i=0
    total_throughput=0
    latency=0
    map5=-1
    map95=-1
    inst_num=0
}
/^FRAMEWORK:/{ framework=$2 }
/^HARDWARE:/{ hardware=$2 }
/^BATCH_SIZE:/{ batch_size=$2 }
/^STEPS:/{ steps=$2 }
/^CORES_PER_INSTANCE/ { cores_per_instance=$2 }
/torch.version:/{ framework_version=$2 }
/tensorrt.version:/{ framework_version=$2 }
/^RECIPE_TYPE:/{ recipe_type=$2 }
/^MODE:/{ mode=$2 }
/^PRECISION:/{ precision=$2 }
/^Throughput/ {
    total_throughput += $2
    latency += (batch_size/$2)
    inst_num+=1

}
/all        5000/{ map95 = $NF }

/] Throughput | Throughput/  {
    split($0, tmp_str, " ")
    total_throughput=tmp_str[4]
}
/] Latency/ {
    split($0, tmp_str, " ")
    min_latency=tmp_str[6]/1000
    max_latency=tmp_str[10]/1000
    mean_latency=tmp_str[14]/1000
    p50_latency=tmp_str[18]/1000
    p90_latency=tmp_str[22]/1000
    p95_latency=tmp_str[26]/1000
    p99_latency=tmp_str[30]/1000
}
/Inference latency/ {
    latency_val=gensub(/.*Inference latency ([0-9]+(\.[0-9]+)?) ms.*/, "\\1", 1, $1);
    print("latency_val->" latency_val)
    if ( latency_val != "" ){
        latency_list[i]=latency_val 
        i+=1
    }
    
}
/Average latency/{ mean_latency=$2 }
/^Min latency/{ min_latency=$2 }
/^Max latency/{ max_latency=$2 }
/^P50 latency/{ p50_latency=$2 }
/^P90 latency/{ p90_latency=$2 }
/^P95 latency/{ p95_latency=$2 }
/^P99 latency/{ p99_latency=$2 }
/^P99.9 latency/{ p999_latency=$2 }


END{
    calculatePLatencies()
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##WORKLOAD_NAME: YOLOv7-PyTorch-Public"
    print "##BASE_MODEL_NAME: YOLOv7"
    print "##RECIPE_TYPE: "recipe_type
    print "##FRAMEWORK: "framework
    print "##FRAMEWORK_VERSION: "framework_version
    print "##HARDWARE: "hardware
    print "##TASK: object detection"
    print "##MODEL_NAME: YOLOv7"
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: WongKinYiu/yolov7"
    print "##DATASET: coco2017"
    print "##FUNCTION: inference"
    print "##MODE: "mode
    print "##PRECISION: "precision
    print "##DATA_TYPE: real"
    print "##BATCH_SIZE: "batch_size
    if ( mode == "accuracy" ){
        print "##INSTANCE_NUMBER: 1"
    }
    else{
        print "##INSTANCE_NUMBER: "inst_num
    }
    print "##CORES_PER_INSTANCE: "cores_per_instance
    print "##INPUT_TOKENS: -1"
    print "##OUTPUT_TOKENS: -1"
    print "##DS_TP: -1"
    print "##STEPS: "steps
    print "##BEAM: -1"

    print "\n#================================================"
    print "#Application Configuration"
    print "#================================================"
    print "##SCENARIO: offline"
    print "##SERVING_STACK: -1"
    print "##MODEL_WORKERS: -1"
    print "##REQUEST_PER_WORKER: -1"

    print "\n#================================================"
    print "#Metrics"
    print "#================================================"
    if (mode != "accuracy" && hardware == "xeon"){
        print "Throughput (img/sec): "total_throughput
        print "Average Latency (sec): "latency/inst_num
    }else{
        print "Throughput (img/sec): -1"
        print "Average Latency (sec): -1"
    }
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
    if ( mode == "accuracy" ){
        print "*""Accuracy(mAP@.5:95):",map95
    }
    else if ( mode == "throughput" ){
        print "*""Throughput (img/sec):",total_throughput
    }
    else {
        print "*""Latency (sec): ",latency/inst_num
    }
}
' $(find . -name "benchmark*.log")  || true
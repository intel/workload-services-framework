#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -F, -e '
BEGIN { 
    printf "#######################\n"
    k_nn=0
    epsilon=0
    largeepsilon=0
    rel=0
    qps=0
    p50=0
    p95=0
    p99=0
    p999=0
}

/^Milvus|redisearch|faiss|hnswlib/ {   
    printf "k-nn: %.5f\n", $4
    printf "epsilon: %.5f\n", $5
    printf "largeepsilon: %.5f\n", $6
    printf "rel: %.5f\n", $7
    printf "qps: %.5f\n", $8
    printf "p50: %.2f\n", $9
    printf "p95: %.2f\n", $10
    printf "p99: %.2f\n", $11
    printf "p999: %.2f\n", $12
    k_nn=$4
    epsilon=$5
    largeepsilon=$6
    rel=$7
    qps=$8
    p50=$9
    p95=$0
    p99=$11
    p999=$12
}
END { 
    printf "#######################\n"    
    printf "*Recall Rate: %.5f\n", k_nn
    printf "QPS:%.2f\n", qps
}' */result.txt 2>/dev/null || true

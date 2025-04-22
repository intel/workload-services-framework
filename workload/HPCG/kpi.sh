#!/bin/bash -e
# Output from generic HPCG 
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
find . -name "HPCG-Benchmark_*.txt" -exec awk -F '=' '

/Final Summary::HPCG result is VALID with a GFLOP\/s rating of=/ {
     print "*Throughput (GFlop/s):"$2;
}

'  "{}" \; 2>/dev/null || true

#Output from Intel HPCG
find . -name "n*.txt" -exec awk -F '=' '

/ Final Summary ::HPCG result is VALID with a GFLOP\/s rating of=/ {
     print "*Throughput (GFlop/s):"$2;
}

'  "{}" \; 2>/dev/null || true

#Output from AMD HPCG
find . -name "output.logs" -exec awk '

/ GFLOP\/s Summary/ {
     print "*Throughput (GFlop/s):"$1;
}

'  "{}" \; 2>/dev/null || true

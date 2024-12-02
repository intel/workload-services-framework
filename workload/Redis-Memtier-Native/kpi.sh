#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

get_instanceid='function get_instanceid(filename){
    match(filename, "[0-9]+\\.log", tmp);
    sub(".log","",tmp[0]);
    return "Instance " tmp[0];
}'

awk -e "$get_instanceid"'
/^Totals/ {
    id=get_instanceid(FILENAME)
    printf "populate: %s ops(ops/sec): %.2f\n", id, $2
    printf "populate: %s hit(hits/sec): %.2f\n", id, $3
    printf "populate: %s missed(misses/sec): %.2f\n", id, $4
    printf "populate: %s latency average (ms): %.5f\n", id, $5
    printf "populate: %s throughput (KB/s): %.2f\n", id, $9
}
' */memtier-populate*.log 2>/dev/null || true

awk -e "$get_instanceid"'
BEGIN { 
    printf "#######################\n"
    total_throughput=0
    total_ops=0
    p99=0
    latency_average=0
    cnt=0 
}
/^Totals/ {
    id=get_instanceid(FILENAME)
    printf "Formal execution: %s ops(ops/sec): %.2f\n", id, $2
    printf "Formal execution: %s hit(hits/sec): %.2f\n", id, $3
    printf "Formal execution: %s missed(misses/sec): %.2f\n", id, $4
    printf "Formal execution: %s latency average (ms): %.5f\n", id, $5
    printf "Formal execution: %s p99 Latency (ms): %.2f\n", id, $7
    printf "Formal execution: %s throughput (KB/s): %.2f\n", id, $9
    total_throughput = total_throughput + $9
    total_ops = total_ops + $2
    p99 = p99 + $7
    latency_average = latency_average + $5
    cnt = cnt + 1
}
END { 
    printf "#######################\n"
    printf "latency average (ms): %.2f\n", latency_average/cnt
    printf "P99 latency(msec): %.2f\n", p99/cnt
    printf "Total Throughput(KB/s): %.2f\n", total_throughput
    printf "*Total OPS(ops/sec): %.2f\n", total_ops
}' */memtier-bench*.log 2>/dev/null || true
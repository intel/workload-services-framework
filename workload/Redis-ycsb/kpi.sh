#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
awk '
BEGIN{
    i=0
}

BEGINFILE {
    i=ARGIND-1
    run_overall_throughput_list[i]=0
    run_cleanup_averagelatency_list[i]=0
    run_read_averagelatency_list[i]=0
    run_read_p99latency_list[i]=0
    run_update_averagelatency_list[i]=0
    run_update_p99latency_list[i]=0
    run_insert_averagelatency_list[i]=0
    run_insert_p99latency_list[i]=0
    run_logs[i]=""
    run_target=""
}

/\[OVERALL\], Throughput/ {
    split($0, throughput, ",")
    run_overall_throughput_list[i]=throughput[3]
}

/\[INSERT\], AverageLatency/ {
    split($0, inst_avl, ",")
    run_insert_averagelatency_list[i]=inst_avl[3]
}

/\[INSERT\], 99thPercentileLatency/ {
    split($0, inst_p99_lat, ",")
    run_insert_p99latency_list[i]=inst_p99_lat[3]
}

/\[READ\], AverageLatency\(us\)/ {
    split($0, read_avl, ",")
    run_read_averagelatency_list[i]=read_avl[3]
}

/\[READ\], 99thPercentileLatency/ {
    split($0, read_p99_lat, ",")
    run_read_p99latency_list[i]=read_p99_lat[3]
}

/\[UPDATE\], AverageLatency\(us\)/ {
    split($0, updt_avl, ",")
    run_update_averagelatency_list[i]=updt_avl[3]
}

/\[UPDATE\], 99thPercentileLatency/ {
    split($0, upd_p99_lat, ",")
    run_update_p99latency_list[i]=upd_p99_lat[3]
}

END{
    sum_of_run_p99_insert_latency=0
    for(i in run_insert_p99latency_list){
        sum_of_run_p99_insert_latency+=run_insert_p99latency_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] P99 insert latency(us): "sum_of_run_p99_insert_latency/length(run_insert_p99latency_list)

    sum_of_run_p99_read_latency=0
    for(i in run_read_p99latency_list){
        sum_of_run_p99_read_latency+=run_read_p99latency_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] P99 read latency(us): "sum_of_run_p99_read_latency/length(run_read_p99latency_list)

    sum_of_run_p99_update_latency=0
    for(i in run_update_p99latency_list){
        sum_of_run_p99_update_latency+=run_update_p99latency_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] P99 update latency(us): "sum_of_run_p99_update_latency/length(run_update_p99latency_list)

    sum_of_run_average_insert_latency=0
    for(i in run_insert_averagelatency_list){
        sum_of_run_average_insert_latency+=run_insert_averagelatency_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] Average insert latency(us): "sum_of_run_average_insert_latency/length(run_insert_averagelatency_list)

    sum_of_run_average_read_latency=0
    for(i in run_read_averagelatency_list){
        sum_of_run_average_read_latency+=run_read_averagelatency_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] Average read latency(us): "sum_of_run_average_read_latency/length(run_read_averagelatency_list)

    sum_of_run_average_update_latency=0
    for(i in run_update_averagelatency_list){
        sum_of_run_average_update_latency+=run_update_averagelatency_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] Average update latency(us): "sum_of_run_average_update_latency/length(run_update_averagelatency_list)

    sum_of_run_throughput=0
    for(i in run_overall_throughput_list){
        sum_of_run_throughput+=run_overall_throughput_list[i]
    }
    print "Mean of [PERFORMANCE PHASE] Throughput(ops/sec): "sum_of_run_throughput/length(run_overall_throughput_list)
    print "*Sum of [PERFORMANCE PHASE] Throughput(ops/sec): "sum_of_run_throughput
}

' $(find . -name 'benchmark_performance*.log') 2>/dev/null || true
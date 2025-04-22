#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# p95 & p99 Latency SLA will be overrided kpi args in validate.sh when run wsf
p95_latency_sla=${1:-20}
p99_latency_sla=${2:-40}

awk -v p95_latency_sla=$p95_latency_sla \
    -v p99_latency_sla=$p99_latency_sla '
BEGIN {
    producer_records_sent[FILENAME] = 0
    producer_records_per_sec[FILENAME] = 0
    producer_MB_per_sec[FILENAME] = 0
    producer_avg_latency[FILENAME] = 0
    producer_max_latency[FILENAME] = 0
    producer_50th[FILENAME] = 0
    producer_95th[FILENAME] = 0
    producer_99th[FILENAME] = 0
    producer_999th[FILENAME] = 0
    maximum_throughput=0
    maximum_throughput_p95_sla=0
    maximum_throughput_p99_sla=0
    number_of_producer=0
    max_p95_latency=0
    min_p95_latency=9999999
    avg_p95_latency=0
    total_p95_latency=0
    max_p99_latency=0
    min_p99_latency=9999999
    avg_p99_latency=0
    total_p99_latency=0
    sum_compression_rate=0
}

#parse producer results
/99.9th/{  
    split($0, a, " ");
    producer_records_sent[FILENAME] = a[1]
    producer_records_per_sec[FILENAME] = a[4]
    gsub(/\(/,"",a[6])
    producer_MB_per_sec[FILENAME] = a[6]
    producer_avg_latency[FILENAME] = a[8]
    producer_max_latency[FILENAME] = a[12]
    producer_50th[FILENAME] = a[16]
    producer_95th[FILENAME] = a[19]
    producer_99th[FILENAME] = a[22]
    producer_999th[FILENAME] = a[25]

    # maximum_throughput is sum of all producer_MB_per_sec
    maximum_throughput += producer_MB_per_sec[FILENAME]
    number_of_producer += 1

    # only add if throughputs 95th is less than FLAG
    if ( producer_95th[FILENAME] < p95_latency_sla ) {
        maximum_throughput_p95_sla += producer_MB_per_sec[FILENAME]
    }

    # only add if throughputs 99th is less than FLAG
    if ( producer_99th[FILENAME] < p99_latency_sla ) {
        maximum_throughput_p99_sla += producer_MB_per_sec[FILENAME]
    }

    if ( producer_95th[FILENAME] > max_p95_latency) {
        max_p95_latency = producer_95th[FILENAME]
    }
    if ( producer_95th[FILENAME] < min_p95_latency) {
        min_p95_latency = producer_95th[FILENAME]
    }
    total_p95_latency += producer_95th[FILENAME]
    if ( producer_99th[FILENAME] > max_p99_latency) {
        max_p99_latency = producer_99th[FILENAME]
    }
    if ( producer_99th[FILENAME] < min_p99_latency) {
        min_p99_latency = producer_99th[FILENAME]
    }
    total_p99_latency += producer_99th[FILENAME]
}

#parse consumer results
/^[0-9]+\-[0-9]+\-[0-9]+/{
    split($0,b,",");
    
    consumer_data_consumed_in_MB[FILENAME] = b[3]
    consumer_MB_sec[FILENAME] = b[4]
    consumer_data_consumed_in_nMsg[FILENAME] = b[5]
    consumer_nMsg_sec[FILENAME] = b[6]
    consumer_rebalance_time_ms[FILENAME] = b[7]
    consumer_fetch_time_ms[FILENAME] = b[8]
    consumer_fetch_MB_sec[FILENAME] = b[9]
    consumer_fetch_nMsg_sec[FILENAME] = b[10]
}

/compression-rate-avg/ {
    split($0, c, ": ");
    sum_compression_rate += c[2]
}

END {
    primary="*"
    avg_p95_latency = total_p95_latency/number_of_producer
    avg_p99_latency = total_p99_latency/number_of_producer
    avg_compression_rate = sum_compression_rate/number_of_producer

    print primary "Maximum Throughput (MB/s): "  maximum_throughput
    print "avg_p95_latency (ms): " avg_p95_latency
    print "avg_p99_latency (ms): " avg_p99_latency
    print "p95 Latency SLA (ms): " p95_latency_sla
    print "p99 Latency SLA (ms): " p99_latency_sla
    print "Maximum Throughput for p95 Latency SLA (MB/s): " maximum_throughput_p95_sla
    print "Maximum Throughput for p99 Latency SLA (MB/s): " maximum_throughput_p99_sla
    print "max_p95_latency (ms): " max_p95_latency
    print "min_p95_latency (ms): " min_p95_latency
    print "max_p99_latency (ms): " max_p99_latency
    print "min_p99_latency (ms): " min_p99_latency
    print "avg_compression_rate of producer: " avg_compression_rate
}


' */producer_output.logs 2>/dev/null || true

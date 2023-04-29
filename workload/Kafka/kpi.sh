#!/bin/bash -e

default_kafka_p95_latency=${kafka_p95_latency:-5}

awk -v kafka_p95_latency=$default_kafka_p95_latency '
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
    maximum_throughput_sla=0
    max_p95_tx_latency=0
    number_of_producer=0
    max_p95_latency=0
    min_p95_latency=9999999
    avg_p95_latency=0
    total_p95_latency=0
    max_p99_latency=0
    min_p99_latency=9999999
    avg_p99_latency=0
    total_p99_latency=0
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
    if ( producer_95th[FILENAME] < kafka_p95_latency ) {
        maximum_throughput_sla += producer_MB_per_sec[FILENAME]
    }

    # if producer_95th is bigger, assign to variable
    if ( producer_95th[FILENAME] > max_p95_tx_latency) {
        max_p95_tx_latency = producer_95th[FILENAME]
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

END {
    primary="*"
    avg_p95_latency = total_p95_latency/number_of_producer
    avg_p99_latency = total_p99_latency/number_of_producer
    print "kafka_p95_latency (ms): " kafka_p95_latency
    print "number_of_producer: " number_of_producer
    print primary "Maximum Throughput (MB/s): "  maximum_throughput
    print "Maximum Throughput for Latency SLA (MB/s): " maximum_throughput_sla
    print "max_p95_tx_latency (ms): " max_p95_tx_latency
    print "max_p95_latency (ms): " max_p95_latency
    print "min_p95_latency (ms): " min_p95_latency
    print "avg_p95_latency (ms): " avg_p95_latency
    print "max_p99_latency (ms): " max_p99_latency
    print "min_p99_latency (ms): " min_p99_latency
    print "avg_p99_latency (ms): " avg_p99_latency
}


' */producer_output.logs 2>/dev/null || true

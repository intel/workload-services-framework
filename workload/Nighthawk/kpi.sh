#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

path=$(find . -name output.logs)

function changeLatencyToMs() {
    latency_s=$(echo "$1" | awk '{print $3}' | awk -F 's' '{print$1}')
    latency_ms=$(echo "$1" | awk '{print $4}' | awk -F 'ms' '{print$1}')
    latency_us=$(echo "$1" | awk '{print $5}' | awk -F 'us' '{print$1}')
    if [ "$2" == "Latency99" ]; then
        printf "*"
    fi
    printf "%s(ms): %s%s.%s\n" "$2" "$latency_s" "$latency_ms" "$latency_us"
}

function printInfo() {
    if [ "$1" == 0.9 ]; then
        # print Latency 9
        Latency=$(awk 'c&&!--c;/Request/{c=7}' $path)
        changeLatencyToMs "$Latency" "Latency9"
    elif [ "$1" == 0.99 ]; then
        # print Latency 99
        Latency=$(awk 'c&&!--c;/Request/{c=9}' $path)
        changeLatencyToMs "$Latency" "Latency99"
    elif [ "$1" == "RPS" ]; then
        # print RPS
        RPS=$(cat $path | grep "benchmark.http_2xx" | awk '{print $3}')
        printf "Requests(Per Second): %s\n" "$RPS"
    fi
}

printInfo 0.9
printInfo 0.99
printInfo RPS

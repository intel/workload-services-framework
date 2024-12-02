#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

type=${1:-readrandomwriterandom}
find . -name "output_$type.log" -exec  awk -v type=$type '
BEGIN {
    total_ops = 0
    p50_get_latency = 0
    p99_get_latency = 0
    p50_put_latency = 0
    p99_put_latency = 0
}

/^Total ops:/ {
    total_ops = $3
}

/^Avg p50_get_latency:/ {
    p50_get_latency = $3
}

/^Avg p99_get_latency:/ {
    p99_get_latency = $3
}

/^Avg p50_put_latency:/ {
    p50_put_latency = $3
}

/^Avg p99_put_latency:/ {
    p99_put_latency = $3
}

END {
    print "*Total OPS:", total_ops
    print "Avg P50 GET Latency:", p50_get_latency
    print "Avg P99 GET Latency:", p99_get_latency
    if (type != "readrandom") {
        print "Avg P50 PUT Latency:", p50_put_latency
        print "Avg P99 PUT Latency:", p99_put_latency
    }
}
' "{}" \; || true
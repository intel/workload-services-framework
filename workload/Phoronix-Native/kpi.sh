#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#!/bin/bash -e

BENCHMARK_WL=${1:-"pts"}

if [[ "$BENCHMARK_WL" == pts/nginx* ]]; then
    parse_common='
    function kvformat(key, value) {
        unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
        value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
        key=gensub(/(.*): *$/,"\\1",1, key);
        if (unit!="") key=key" ("unit")";
        return key": "value;
    }
    '

    parse_wrk_kpi () {
        find $1 -name "*.log" -exec awk -e "$parse_common" -e '
    BEGIN {
        dist=0
    }
    /threads/&&/connections/{
        print kvformat("threads",$1);
        print kvformat("connections",$4);
    }
    /Latency/ && NF==5 {
        print kvformat("latency avg",$2);
        print kvformat("latency std",$3);
        print kvformat("latency max",$4);
        print kvformat("latency std%",$5);
    }
    /Req\/Sec/ && NF==5 {
        print kvformat("req/s avg (reqs/s)",$2);
        print kvformat("req/s std (reqs/s)",$3);
        print kvformat("req/s max (reqs/s)",$4);
        print kvformat("req/s std%",$5);
    }
    /Latency Distribution/{
        dist=1
    }
    (/90%/ || /99%/ || /50%/ || /75%/ || /000%/) && dist==1 {
        print kvformat("latency "$1,$2);
    }
    /requests in/ && /read/ {
        print "requests: "$1
        print kvformat("duration",gensub(/,/,"",1,$4))
        print kvformat("read",$5)
    }
    /Non-2xx or 3xx responses:/ {
        print "failed: "$5
    }
    /Requests\/sec:/ || /Transfer\/sec/ {
        if ($1~/Transfer/) {
            $2=$2"/s"
        } else {
            $1="*"$1
            $2=$2"reqs/s"
        }
        print kvformat($1,$2);
    }
    ' "{}" \;
    }

    parse_wrk_kpi "test-results/pts/nginx-*/*/test-logs/*/" || true;
fi

if [[ "$BENCHMARK_WL" == pts/stream* ]]; then
    awk '
    function kvformat(key, value) {
        unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
        value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
        key=gensub(/(.*): *$/,"\\1",1, key);
        if (unit!="") key=key" ("unit")";
        return key": "value;
    }
    BEGIN {
        max_triad=0
    }
    /^Copy/ && NF==5 {
        copy_rate=$2
        copy_avg_time=$3
        copy_min_time=$4
        copy_max_time=$5
    }
    /^Scale/ && NF==5 {
        scale_rate=$2
        scale_avg_time=$3
        scale_min_time=$4
        scale_max_time=$5
    }
    /^Add/ && NF==5 {
        add_rate=$2
        add_avg_time=$3
        add_min_time=$4
        add_max_time=$5
    }
    /^Triad/ && NF==5 {
        triad_rate=$2
        triad_avg_time=$3
        triad_min_time=$4
        triad_max_time=$5
        if (triad_rate+0 > max_triad+0) {
            max_triad=triad_rate
            best_copy_rate=copy_rate
            best_copy_avg_time=copy_avg_time
            best_copy_min_time=copy_min_time
            best_copy_max_time=copy_max_time
            best_scale_rate=scale_rate
            best_scale_avg_time=scale_avg_time
            best_scale_min_time=scale_min_time
            best_scale_max_time=scale_max_time
            best_add_rate=add_rate
            best_add_avg_time=add_avg_time
            best_add_min_time=add_min_time
            best_add_max_time=add_max_time
            best_array_size=array_size
            best_total_memory=total_memory
            best_threads_requested=threads_requested
            best_threads_counted=threads_counted
        }
    }
    /^Array size/ {
        array_size=$4
    }
    /^Total memory required/ {
        total_memory=$5
    }
    /^Number of Threads requested/ {
        threads_requested=$6
    }
    /^Number of Threads counted/ {
        threads_counted=$6
    }
    END {
        print kvformat("*Maximum Triad Best Rate (MB/s)", max_triad)
        print kvformat("Copy Best Rate (MB/s)", best_copy_rate)
        print kvformat("Copy Avg time (s)", best_copy_avg_time)
        print kvformat("Copy Min time (s)", best_copy_min_time)
        print kvformat("Copy Max time (s)", best_copy_max_time)
        print kvformat("Scale Best Rate (MB/s)", best_scale_rate)
        print kvformat("Scale Avg time (s)", best_scale_avg_time)
        print kvformat("Scale Min time (s)", best_scale_min_time)
        print kvformat("Scale Max time (s)", best_scale_max_time)
        print kvformat("Add Best Rate (MB/s)", best_add_rate)
        print kvformat("Add Avg time (s)", best_add_avg_time)
        print kvformat("Add Min time (s)", best_add_min_time)
        print kvformat("Add Max time (s)", best_add_max_time)
        print kvformat("Array size (elements)", best_array_size)
        print kvformat("Total memory required (MiB)", best_total_memory)
        print kvformat("Number of Threads requested", best_threads_requested)
        print kvformat("Number of Threads counted", best_threads_counted)
    }
    ' test-results/pts/stream-*/*/test-logs/*/*.log 2>/dev/null || true
fi

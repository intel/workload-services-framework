#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
BEGIN {
    cpu_speed="";
    memory_throughput_avg="";
    mysql_latency_avg="";
    mutex_avg="";
}

/CPU speed:/{
    while(1){
        getline;
        if(/events per second:/){
            cpu_speed=kvformat("*The CPU speed (events per second): ",$4);
            break;
        }
        else {continue}
    }
}

/Running memory speed test with the following options:/{
    while(1){
        getline;
        if(/Total operations:/){
            FS="(";
            getline;
            getline;
            memory_throughput_avg=kvformat("*The Memory average throughput (MiB/sec): ",$2);
            break;
        }
        else {continue}
    }
}

/SQL statistics:/{
    while(1){
        getline;
        if(/avg:/){
        mysql_latency_avg=kvformat("*The MYSQL average latency time (ms): ", $2)
            break;
        }
        else {continue}
    }
}

/Threads fairness:/{
    while(1){
        getline;
        if(/execution time \(avg\/stddev\):/){
        mutex_avg=kvformat("*The Mutex execution time (avg/stddev) (ms): ", $4);
            break;
        }
        else {continue}
    }
}

END {
    if(cpu_speed != "")
    {
        print cpu_speed;
    }
    if (memory_throughput_avg !=""){
        print memory_throughput_avg;
    }
    if (mysql_latency_avg !=""){
        print mysql_latency_avg;
    }
    if (mutex_avg !=""){
        print mutex_avg;
    }
}
' */output.logs 2>/dev/null || true

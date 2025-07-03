#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# --- Metadata Extraction ---
awk '
/^Topology:/ {Topology=$2}
/^Mode:/ {Mode=$2}
/^Function:/ {Function=$2}
/^Data Type:/ {Data_Type=$3}
/^Precision:/ {Precision=$2}
/^Batch Size:/ {Batch_Size=$3}
/^Steps:/ {Steps=$2}
END {
    print "# Topology: "Topology
    print "# Mode: "Mode
    print "# Function: "Function
    print "# Data Type: "Data_Type
    print "# Precision: "Precision
    print "# Batch Size: "Batch_Size
    print "# Steps: "Steps
}
' */benchmark_*.log 2>/dev/null


# --- KPI Extraction ---
awk '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value)
    key=gensub(/(.*): *$/,"\\1",1, key);
    return key": "value;
}
BEGIN {
    sum=0
    count=0
}
/^recall/{
    print kvformat("Accuracy (%)",$10)
}
/^Latency/{
    print kvformat("Latency (msec/sentence)",$2)
}
/^Samples per second:/{
    count+=1
    print kvformat("Throughput"count" (Sample/second)",$4)
    sum+=$4
}
END {
    if (sum != 0)
        print kvformat("*Throughput (Sample/second)", sum)
}
' */benchmark_*.log 2>/dev/null || true

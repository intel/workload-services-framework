#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Define the log file path
log_file="*/doris_benchmark.log"

# Temporary files for KPI values
ssb_kpi_tmp=$(mktemp)
flat_kpi_tmp=$(mktemp)

# Set cleanup trap
trap 'rm -f "$ssb_kpi_tmp" "$flat_kpi_tmp"' EXIT

# Extract SSB query times (simplified to only show KPI)
cat $log_file | grep -B13 '^ssb queries end' | awk -v out="$ssb_kpi_tmp" '
BEGIN {
    cold_run_time = 0;
    hot_run_time = 0;
}
/Total cold run time/ {
    match($0, /[0-9]+ ms/, arr);
    cold_run_time = substr(arr[0], 1, length(arr[0]) - 3) / 1000;
}
/Total hot run time/ {
    match($0, /[0-9]+ ms/, arr);
    hot_run_time = substr(arr[0], 1, length(arr[0]) - 3) / 1000;
}
END {
    kpi = (cold_run_time + hot_run_time) / 2;
    print "SSB Query KPI (Average of Cold and Hot Runs): " kpi;
    print kpi > out;
}'

# Extract Flat SSB query times (primary KPI only)
cat $log_file | grep -B13 '^flat ssb queries end' | awk -v out="$flat_kpi_tmp" '
BEGIN {
    cold_run_time = 0;
    hot_run_time = 0;
}
/Total cold run time/ {
    match($0, /[0-9]+ ms/, arr);
    cold_run_time = substr(arr[0], 1, length(arr[0]) - 3) / 1000;
}
/Total hot run time/ {
    match($0, /[0-9]+ ms/, arr);
    hot_run_time = substr(arr[0], 1, length(arr[0]) - 3) / 1000;
}
END {
    kpi = (cold_run_time + hot_run_time) / 2;
    # Primary KPI line marked with *
    primary = "*";
    print primary "Flat SSB Query KPI (Average of Cold and Hot Runs): " kpi;
    print kpi > out;
}' || true

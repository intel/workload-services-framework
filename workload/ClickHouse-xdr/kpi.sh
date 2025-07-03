#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value)
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}

function basename(file) {
    n=split(file, a, "/")
    return a[n]
}

BEGIN {
    i=0
    total_time=0
    query_num=5
}

/real/ {
    split(basename(FILENAME), file_names, "_")
    query_list[i]=file_names[1]
    split($0, result, " ")
    real_time[i]=result[2]
    i=i+1
}

END {
    for (j = 0; j < i; j++) {
        printf("Query '\''%s'\''", query_list[j])
        print kvformat(" execution time(s):",real_time[j])
        if ( query_list[j] ~ "query[1-5]" ) {
            total_time += real_time[j]
        }
    }
    print kvformat("*Average execution time of query1 to query5(s):", sprintf("%.3f", total_time / query_num))
}
' */*/*_results.logs || true

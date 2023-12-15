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
    FS = "|"
    power_test_time=0
    tput_test_time=0
    QphDS=0
    score=0
}

/Test execution time:/{
    split($0,result," ")
    print kvformat("*Test execution time (min)",result[4]);
}

/Data generation time:/{
    split($0,result," ")
    print kvformat("Data generation time (min)",result[4]);
}

/Print results:/{
    line = NR
}

NR > line+3 && /^(\|[0-9]+)/{
    split($2,query,"-")
    name = sprintf("Query %s (s)", query[1])
    value = sprintf("%.5f", $3)
    print kvformat(name,value);
}

' */output.logs 2>/dev/null || true

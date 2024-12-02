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

/WC00C2R2/ {
    printf("*""Throughput (GF/s): %0.2f\n",$7)
    print kvformat("Runtime",$6 "seconds")
    print kvformat("N",$2)
    print kvformat("NB",$3)
    print kvformat("P",$4)
    print kvformat("Q",$5)
}

/WR0XR8C48/ {
    printf("*""Throughput (GF/s): %0.2f\n",$7)
    print kvformat("Runtime",$6 "seconds")
    print kvformat("N",$2)
    print kvformat("NB",$3)
    print kvformat("P",$4)
    print kvformat("Q",$5)
}

/WR07R8C48o/ {
    printf("*""Throughput (GF/s): %0.2f\n",$8)
    print kvformat("Runtime",$7 "seconds")
    print kvformat("N",$3)
    print kvformat("NB",$4)
    print kvformat("P",$5)
    print kvformat("Q",$6)
}

/WR00L2L2/ {
    printf("*""Throughput (GF/s): %0.2f\n",$7)
    print kvformat("Runtime",$6 "seconds")
    print kvformat("N",$2)
    print kvformat("NB",$3)
    print kvformat("P",$4)
    print kvformat("Q",$5)
}

' */output.logs 2>/dev/null || true


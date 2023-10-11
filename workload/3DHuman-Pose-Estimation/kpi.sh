#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
# output KPIs as "key: value" or "key (unit): value"
# value: int || float
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value)
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}

/^average latency/{
    print kvformat("*average latency(ms): ", $3)
}

/^average fps/{
    print kvformat("average fps: ", $3)
}

' */output.logs 2>/dev/null || true

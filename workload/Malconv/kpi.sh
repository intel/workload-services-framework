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

BEGIN{
    inference_time=0
    standard_deviation=0
    AUC=0
    instance=0
}
/inference/ {
    inference_time=inference_time+$4
}
/AUC/ {
    AUC=AUC+$4
}
/instance/{
    instance=instance+$3
}
END {
    print "*inference time (ms): "inference_time
    print "throughput(file per second): "instance*1000/inference_time
    print "AUC: "AUC
}' */out* 2>/dev/null || true
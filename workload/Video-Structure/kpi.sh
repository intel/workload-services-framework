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
/^h264 average fps/{
    print kvformat("h264 average fps: ", $4)
}


/^h265 average fps/{
    print kvformat("h265 average fps: ", $4)
}
/^h265 streams/{
    print kvformat("h265 streams: ", $3)
}
/^h264 streams/{
    print kvformat("*h264 streams: ", $3)
}

/fail/ {
    fail=fail+1
}



' */out* 2>/dev/null || true

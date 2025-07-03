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

/^SGEMM Performance N.*/ {
    print kvformat( "*""SGEMM Performance(GF/s)", $7)
}
/^DGEMM Performance N.*/ {
    print kvformat( "*""DGEMM Performance(GF/s)", $7)
}

' */output.log 2>/dev/null || true


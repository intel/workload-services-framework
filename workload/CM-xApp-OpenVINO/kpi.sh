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

/Number of Cells/{
    print $0
}
/Pre HO/ {
    print $0
}
/OpenVINO HO/ {
    print $0
}
/Post HO/ {
    print $0
}
/Total HO/ {
    print $0
}
' */output.logs 2>/dev/null || true


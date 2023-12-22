#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

FILE_SIZE=${1:-"1MB"}

parse_common='
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
'

parse_wrk_kpi_10KB () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/10KBRequests\/sec/ {
    print kvformat("10KB Requests/sec:", $2)
}
/10KBTransfer\/sec/ {
    print kvformat("10KB Transfer/sec:", $2)
}
/10KB90%/ {
    print kvformat("10KB Latency 90%:", $2)
}
/10KB99%/ {
    print kvformat("10KB Latency 99%:", $2)
}
/10KBLatency   / {
    print kvformat("*10KB Latency Avg:", $2)
}
' "{}" \;
}

parse_wrk_kpi_100KB () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/100KBRequests\/sec/ {
    print kvformat("100KB Requests/sec:", $2)
}
/100KBTransfer\/sec/ {
    print kvformat("100KB Transfer/sec:", $2)
}
/100KB90%/ {
    print kvformat("100KB Latency 90%:", $2)
}
/100KB99%/ {
    print kvformat("100KB Latency 99%:", $2)
}
/100KBLatency   / {
    print kvformat("*100KB Latency Avg:", $2)
}
' "{}" \;
}

parse_wrk_kpi_1MB () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/1MBRequests\/sec/ {
    print kvformat("1MB Requests/sec:", $2)
}
/1MBTransfer\/sec/ {
    print kvformat("1MB Transfer/sec:", $2)
}
/1MB90%/ {
    print kvformat("1MB Latency 90%:", $2)
}
/1MB99%/ {
    print kvformat("1MB Latency 99%:", $2)
}
/1MBLatency   / {
    print kvformat("*1MB Latency Avg:", $2)
}
' "{}" \;
}

parse_wrk_kpi_mix () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/10KBRequests\/sec/ {
    print kvformat("10KB Requests/sec:", $2)
}
/10KBTransfer\/sec/ {
    print kvformat("10KB Transfer/sec:", $2)
}
/10KB90%/ {
    print kvformat("10KB Latency 90%:", $2)
}
/10KB99%/ {
    print kvformat("10KB Latency 99%:", $2)
}
/10KBLatency   / {
    print kvformat("*10KB Latency Avg:", $2)
}
/100KBRequests\/sec/ {
    print kvformat("100KB Requests/sec:", $2)
}
/100KBTransfer\/sec/ {
    print kvformat("100KB Transfer/sec:", $2)
}
/100KB90%/ {
    print kvformat("100KB Latency 90%:", $2)
}
/100KB99%/ {
    print kvformat("100KB Latency 99%:", $2)
}
/100KBLatency   / {
    print kvformat("100KB Latency Avg:", $2)
}
/1MBRequests\/sec/ {
    print kvformat("1MB Requests/sec:", $2)
}
/1MBTransfer\/sec/ {
    print kvformat("1MB Transfer/sec:", $2)
}
/1MB90%/ {
    print kvformat("1MB Latency 90%:", $2)
}
/1MB99%/ {
    print kvformat("1MB Latency 99%:", $2)
}
/1MBLatency   / {
    print kvformat("1MB Latency Avg:", $2)
}
' "{}" \;
}

if [ "$FILE_SIZE" = "10KB" ]; then
  parse_wrk_kpi_10KB "output.logs" || true
elif [ "$FILE_SIZE" = "100KB" ]; then
  parse_wrk_kpi_100KB "output.logs" || true
elif [ "$FILE_SIZE" = "1MB" ]; then
  parse_wrk_kpi_1MB "output.logs" || true
else
  parse_wrk_kpi_mix "output.logs" || true
fi

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


parse_common='
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
'

parse_wrk_kpi () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
BEGIN {
    dist=0
}
/threads/&&/connections/{
    print kvformat("threads",$1);
    print kvformat("connections",$4);
}
/Latency/ && NF==5 {
    print kvformat("latency avg",$2);
    print kvformat("latency std",$3);
    print kvformat("latency max",$4);
    print kvformat("latency std%",$5);
}
/Req\/Sec/ && NF==5 {
    print kvformat("req/s avg (reqs/s)",$2);
    print kvformat("req/s std (reqs/s)",$3);
    print kvformat("req/s max (reqs/s)",$4);
    print kvformat("req/s std%",$5);
}
/Latency Distribution/{
    dist=1
}
(/90%/ || /99%/ || /50%/ || /75%/ || /000%/) && dist==1 {
    print kvformat("latency "$1,$2);
}
/requests in/ && /read/ {
    print "requests: "$1
    print kvformat("duration",gensub(/,/,"",1,$4))
    print kvformat("read",$5)
}
/Non-2xx or 3xx responses:/ {
    print "failed: "$5
}
/Requests\/sec:/ || /Transfer\/sec/ {
    if ($1~/Transfer/) {
        $2=$2"/s"
    } else {
        $2=$2"reqs/s"
    }
    print kvformat($1,$2);
}
' "{}" \;
}


parse_wrk_kpi "output1.log" || true

echo "$(grep -F "Transfer/sec" */output1.log | tail -n1)" > throughput1.txt

parse_wrk_kpi "throughput1.txt" > throughput.txt || true

cat throughput.txt | awk '{sum += $3} END {print "*Total throughput " $2 " " sum}'

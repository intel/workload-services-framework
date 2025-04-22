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

parse_siege_kpi () {
    awk -e "$parse_common" -e '
/Transactions:/ {
    print kvformat("transactions (hits)",$2);
}
/Availability:/ {
    print kvformat("availability (%)",$2);
}
/Elapsed time:/{
    print kvformat("elapsed_time (s)",$3);
}
/Data transferred:/ {
    print kvformat("data_transferred (MB)",$3)
}
/Response time:/ {
    print kvformat("response_time (s)",$3)
}
/Transaction rate:/ {
    print kvformat("*transaction_rate (trans/s)",$3)
}
/Throughput:/ {
    print kvformat("throughput (MB/sec)",$2)
}
/Concurrency:/ {
    print kvformat("concurrency",$2)
}
/Successful transactions:/ {
    print kvformat("successful_transactions:",$3)
}
/Failed transactions:/ {
    print kvformat("failed_transactions:",$3)
}
/Longest transaction:/{
    print kvformat("longest_transaction (s)", $3)
}
/Shortest transaction:/{
    print kvformat("shortest_transaction (s)", $3)
}
' */$1
}

parse_siege_kpi siege_performance.log 2>/dev/null || true
#!/bin/bash -e

parse_common='
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
'

parse_iperf3_kpi () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/ sender/ {
    print kvformat("Sender Bitrate(Mbits/sec):", $7)
}
/ receiver/ {
    print kvformat("*Receiver Bitrate(Mbits/sec):", $7)
}
/CPU Utilization/ {
    print kvformat("Sender CPU Utilization(%):", $4)
    print kvformat("Receiver CPU Utilization(%):", $7)
}
' "{}" \;
}

parse_iperf2_kpi () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/\[SUM\]/ {
    print kvformat("Sample Time: ", $2 $3)
    print kvformat("Transfer: ", $4 $5)
    print kvformat("*Bandwidth: ", $6 $7)
}
' "{}" \;
}

parse_iperf2_kpi "output.logs" || true

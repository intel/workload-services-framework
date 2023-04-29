#!/bin/bash -e

#echo a:$?
#echo b:$@
#echo c:$1

MODE=${1:-https}
CLIENT_TYPE=${2:-ab}

#echo $MODE
#echo $CLIENT_TYPE

parse_common='
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
'

parse_openssl_kpi () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/_Nginx_core_number/ {
    print kvformat($1,$2)
}
/OpenSSL_test_client_number/ {
    print kvformat("OpenSSL test processes number",$2)
}
/OpenSSL_s_time_test_period/ {
    print kvformat("OpenSSL s_time test seconds",$2)
}
/Connections_per_second/ {
    print kvformat("*Connections per second",$2)
}
/Test_case_cost_seconds/ {
    print kvformat("Test case cost seconds",$2)
}
' "{}" \;
}


parse_ab_kpi () {
    find . -name "$1" -exec awk -e "$parse_common" -e '
/Nginx_Worker_Number/ {
    print kvformat($1,$2)
}
/_Configured_Core_Number/ {
    print kvformat($1,$2)
}
/_Reqeuest_per_vclient/ {
    print kvformat($1,$2)
}
/_Concurrency_per_vclient/ {
    print kvformat($1,$2)
}
/_Complete_requests/ {
    print kvformat($1,$2)
}
/_Failed_requests/ {
    print kvformat($1,$2)
}
/_Total_transferred/ {
    print kvformat("Client transferred (bytes)",$2)
}
/_HTML_transferred/ {
    print kvformat("Client HTML transferred (bytes)",$2)
}
/_requests_per_second/ {
    print kvformat($1,$2)
}
/Client_Stress_Latency_Min/ {
    print kvformat("Client Stress Latency Min (ms)",$2)
}
/Client_Stress_Latency_Mean/ {
    print kvformat("Client Stress Latency Mean (ms)",$2)
}
/Client_Stress_Latency_StdV/ {
    print kvformat("Client Stress Latency Std",$2)
}
/Client_Stress_Latency_Median/ {
    print kvformat("Client Stress Latency Median (ms)",$2)
}
/Client_Stress_Latency_Max/ {
    print kvformat("Client Stress Latency Max (ms)",$2)
}
/Client_Node_Total_Requests_per_second/ {
    print kvformat("*Total requests per second (Requests/s)",$2)
}
' "{}" \;
}

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

# https
if [ ${CLIENT_TYPE} == "openssl" ]; then
parse_openssl_kpi "output.logs" || true;
else
parse_ab_kpi "output.logs" || true;
fi

# http
#parse_wrk_kpi "output.logs" || true

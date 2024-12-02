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
BEGIN {
    Siege_workers=0
    Transactions=0
    Availability=0
    Elapsed_time=0
    Data_transferred=0
    Response_time=0
    Transaction_rate=0
    Throughput=0
    Concurrency=0
    Successful_transactions=0
    Failed_transactions=0
    Longest_transaction=0
    Shortest_transaction=0
}

/Siege workers/{
    Siege_workers+=$3
}


/Transactions/{
    Transactions+=$2
}

/Availability/{
    Availability+=$2
}

/Elapsed time/{
    Elapsed_time+=$3
}

/Data transferred/{
    Data_transferred+=$3
}

/Response time/{
    Response_time+=$3
}

/Transaction rate/{
    Transaction_rate+=$3
}

/Throughput/{
    Throughput+=$2
}

/Concurrency/{
    Concurrency+=$2
}

/Successful transactions/{
    Successful_transactions+=$3
}

/Failed transactions/{
    Failed_transactions+=$3
}

/Longest transaction/{
    Longest_transaction+=$3
}

/Shortest transaction/{
    Shortest_transaction+=$3
}

END {	
	print kvformat("Transactions (hits)",Transactions);
	print kvformat("Availability (%)",Availability);
	print kvformat("Elapsed time (secs)",Elapsed_time);
	print kvformat("Data transferred (MB)",Data_transferred);
	print kvformat("Response time (secs)",Response_time);
	print kvformat("*Transaction rate (trans/sec)",Transaction_rate);
	print kvformat("Throughput (MB/sec)",Throughput);
	print kvformat("Concurrency",Concurrency);
	print kvformat("Successful transactions",Successful_transactions);
	print kvformat("Failed transactions",Failed_transactions);
	print kvformat("Longest transaction",Longest_transaction);
	print kvformat("Shortest transaction",Shortest_transaction);
}
' */output.log 2>/dev/null || true

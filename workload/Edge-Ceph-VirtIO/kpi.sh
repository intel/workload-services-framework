#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TEST_OPERATION=${1:-"sequential_read"}

if [[ "${TEST_OPERATION}" =~ "gated" ]]; then
    vm_num=1
else
    vm_num=$(ls -lR ./edge*| grep ubuntu |grep "^d" | wc -l)
fi

if [[ "${TEST_OPERATION}" =~ "sequential" ]]; then
    # Block IO sequential R/W, the primary kpi is the bandwidth.
    flag_bw="*"
    res=($(find . -name *sequential*.log -exec awk '
    BEGIN {
        test_round=0;
    }

    function kvformat(key, value) {
        unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
        value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
        key=gensub(/(.*): *$/,"\\1",1, key);
        if (unit!="") key=key" ("unit")";
        return key": "value;
    }

    #args:
    # key - kpi type, eg. IOPS/Throught
    # value - equation with unit, eg. avgbw=100MiB
    function equation_kvformat(key, value) {
        key_type=gensub(/(.*)=(.*)/,"\\1",1, value);
        #print "type:"key_type
        pre_value=gensub(/(.*)=(.*)/,"\\2",1, value);
        #print "pre_value:"pre_value
        unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, pre_value);
	    #print "unit:"unit
	    unit=unit"IO/s"
	    value=gensub(/^([0-9+-.]+).*/,"\\1",1, pre_value);
	    #print value
        key=gensub(/(.*): *$/,"\\1",1, key);
        #key=key"-"key_type
        if (unit!="") key=key" ("unit")";
        return key": "value;
    }

    /IOPS/ {

        #format equation
	    kv=gensub(/(.*)=(.*)*,/,"\\1=\\2",1, $2);
        #print "format kv:"kv
        print equation_kvformat("IOPS", kv)

    }

    /BW=/ {
        pattern="BW="
        bw_value=gensub(/BW=(.*)/,"\\1",1, $3)
        #print bw_value
        print kvformat("Throughput", bw_value)
    }

    END {
        #print "test round:\t"test_round;
    }

    ' "{}" \; || true ))
elif [[ "${TEST_OPERATION}" =~ "random" || "${TEST_OPERATION}" =~ "gated" || "${TEST_OPERATION}" =~ "live" ]]; then
    # Block IO sequential R/W, the primary kpi is the bandwidth.
    flag_iops="*"
    res=($(find . -name *random*.log  -exec awk '
    BEGIN {
        test_round=0;
    }
    function kvformat(key, value) {
        unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
        value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
        key=gensub(/(.*): *$/,"\\1",1, key);
        if (unit!="") key=key" ("unit")";
        return key": "value;
    }
    #args:
    # key - kpi type, eg. IOPS/Throught
    # value - equation with unit, eg. avgbw=100MiB
    function equation_kvformat(key, value) {
        key_type=gensub(/(.*)=(.*)/,"\\1",1, value);
        #print "type:"key_type
        pre_value=gensub(/(.*)=(.*)/,"\\2",1, value);
        #print "pre_value:"pre_value
        unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, pre_value);
	    unit=unit"IO/s"
        value=gensub(/^([0-9+-.]+).*/,"\\1",1, pre_value);
        key=gensub(/(.*): *$/,"\\1",1, key);
        #key=key"IOPS"
        if (unit!="") key=key" ("unit")";
        return key": "value;
    }
    /IOPS/ {
        #format equation
        kv=gensub(/(.*)=(.*)*,/,"\\1=\\2",1, $2);
        #print "format kv:"kv
        print equation_kvformat("IOPS", kv)
    }
    /BW=/ {
        pattern="BW="
        bw_value=gensub(/BW=(.*)/,"\\1",1, $3)
        #print bw_value
        print kvformat("Throughput", bw_value)
    }
    END {
        #print "test round:\t"test_round;
    }
    ' "{}" \; || true ))

fi

# Content for res:
# ${res[((6 * $i))]}: kpi name (IOPS)
# ${res[((6 * $i)+1)]}: kpi unit (e.g. kIO/s)
# ${res[((6 * $i)+2)]}: kpi value
# ${res[((6 * $i)+3)]}: kpi name (BW)
# ${res[((6 * $i)+4)]}: kpi unit (e.g. MiB/s)
# ${res[((6 * $i)+5)]}: kpi value

# Output kpi of each VM
i=0
while [ "$i" -lt "$vm_num" ];do
    echo "${res[((6 * $i))]} ${res[((6 * $i)+1)]} ${res[((6 * $i)+2)]}"
    echo "${res[((6 * $i)+3)]} ${res[((6 * $i)+4)]} ${res[((6 * $i)+5)]}"
    i=$(($i+1))
done

# Sum the kpi and output final kpi
awk -v array="${res[*]}" -v vm_num=$vm_num -v flag_iops=$flag_iops -v flag_bw=$flag_bw '
BEGIN{
    split(array,res," ");
    res_len = length(res)
    if(res_len >= 1 && vm_num >= 1){
        for(i=0;i<vm_num;i++){
            if(index(res[((6*i+2))], "k") != 0)
                IOPS = IOPS + res[((6*i+3))] * 1000
            else
                IOPS = IOPS + res[((6*i+3))]
            if(index(res[((6*i+5))], "M") != 0)
                BW = BW + res[((6*i+6))] * 1024
            else
                BW = BW + res[((6*i+6))]
        }
        if(index(res[2], "k") != 0)
            IOPS = IOPS / 1000
        if(index(res[5], "M") != 0)
            BW = BW / 1024
        printf("%s%s %s %s\n",flag_iops,res[1],res[2],IOPS)
        printf("%s%s %s %s\n",flag_bw,res[4],res[5],BW)
    }
}'

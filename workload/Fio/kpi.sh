#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TEST_TYPE=${1:-"sequential_read"}

if [[ "${TEST_TYPE}" =~ "sequential" || "${TEST_TYPE}" =~ "gated" ]]; then
    # Block IO sequential R/W and gated, the primary kpi is the bandwidth.
    find . -name "output.logs" -exec awk '
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

    /IOPS=/ {
        #format equation
        kv=gensub(/(.*)=(.*)*,/,"\\1=\\2",1, $2);
        #print "format kv:"kv
        print equation_kvformat("IOPS", kv)
    }

    /BW=/ {
        pattern="BW="
        bw_value=gensub(/BW=(.*)/,"\\1",1, $3)
        #print bw_value
        print kvformat("*Bandwidth", bw_value)
    }

    END {
        #print "test round:\t"test_round;
    }

    ' "{}" \; || true
elif [[ "${TEST_TYPE}" =~ "random" ]]; then
    # Block IO random R/W, the primary kpi is the IOPS.
    find . -name "output.logs" -exec awk '
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

    /IOPS=/ {
        #format equation
        kv=gensub(/(.*)=(.*)*,/,"\\1=\\2",1, $2);
        #print "format kv:"kv
        print equation_kvformat("*IOPS", kv)
    }

    /BW=/ {
        pattern="BW="
        bw_value=gensub(/BW=(.*)/,"\\1",1, $3)
        #print bw_value
        print kvformat("Bandwidth", bw_value)
    }

    END {
        #print "test round:\t"test_round;
    }

    ' "{}" \; || true

fi 

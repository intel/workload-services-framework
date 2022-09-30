#!/bin/bash -e

awk -vtest_case="$1" '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
/:aes-[0-9]+-cbc-/ {
    algorithm=gensub(/.*:(aes-[0-9]+-cbc-hmac-sha[0-9]+):.*/,"\\1",1)
}
/:aes-[0-9]+-gcm/ {
    algorithm=gensub(/.*:(aes-[0-9]+-gcm):.*/,"\\1",1)
}
/^options:/ {
    for (i=1;i<=NF;i++)
        options[i+1]=(i==1)?gensub(/options:(.*)/,"\\1",1,$i):$i
}
/^evp/ {
    for (i=2;i<=NF;i++) {
        if (test_case~"sw_aes-gcm")
        {
            primary=((algorithm~/aes-256-gcm/)&&(options[i]~/aes/))?"*":""
        }
        else
        {
            primary=((algorithm~/aes-256-.*-sha256/)&&(options[i]~/aes/))?"*":""
        }
        print primary algorithm" "kvformat(options[i],$i)
    }
}
(/^rsa/ || /^dsa/) && NF==7 {
    primary=($2=="2048")?"*":""
    print kvformat($1"-"$2" sign",$4)
    print kvformat($1"-"$2" verify",$5)
    print primary kvformat($1"-"$2" sign/s",$6)
    print kvformat($1"-"$2" verify/s",$7)
}
/ecdh/ && NF==6 {
    if (!($0~/infs/)) {
        primary=($4~"X25519")?"*":""     # x25519 is the only common tested algorithm for qatsw/sw test cases

        print kvformat($3"-"$1" "$4" op",$5)
        print primary kvformat($3"-"$1" "$4" op/s",$6)
    }
}
/ecdsa/ && NF==8 {
    if (!($0~/infs/)) {
        primary=($4~"nistp256")?"*":""
        print kvformat($3"-"$1" "$4" sign",$5)
        print kvformat($3"-"$1" "$4" verify",$6)
        print primary kvformat($3"-"$1" "$4" sign/s",$7)
        print kvformat($3"-"$1" "$4" verify/s",$8)
    }
}
' */output.logs 2>/dev/null || true

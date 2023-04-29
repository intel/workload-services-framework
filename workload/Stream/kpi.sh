#!/bin/bash -e

awk '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
/^Copy/ && NF==5 {
    print kvformat("Copy Best Rate (MB/s)",$2)
    print kvformat("Copy Avg time (s)",$3)
    print kvformat("Copy Min time (s)",$4)
    print kvformat("Copy Max time (s)",$5)
}
/^Scale/ && NF==5 {
    print kvformat("Scale Best Rate (MB/s)",$2)
    print kvformat("Scale Avg time (s)",$3)
    print kvformat("Scale Min time (s)",$4)
    print kvformat("Scale Max time (s)",$5)
}
/^Add/ && NF==5 {
    print kvformat("Add Best Rate (MB/s)",$2)
    print kvformat("Add Avg time (s)",$3)
    print kvformat("Add Min time (s)",$4)
    print kvformat("Add Max time (s)",$5)
}
/^Triad/ && NF==5 {
    print kvformat("*Triad Best Rate (MB/s)",$2)
    print kvformat("Triad Avg time (s)",$3)
    print kvformat("Triad Min time (s)",$4)
    print kvformat("Triad Max time (s)",$5)
}
' */output.logs 2>/dev/null || true

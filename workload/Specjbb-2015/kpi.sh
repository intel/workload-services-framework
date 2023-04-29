#!/bin/bash -e

awk -v pki_type=$(awk '{ sub(/pki_type=/, ""); print }' */output.run.log) '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value)
    key=gensub(/(.*): *$/,"\\1",1, key);
    #if (unit!="") key=key" ("unit")";
    if (value == "N/A" || value == "") value=0;
    return key": "value;
}
/^RUN RESULT:.*/ {
    gsub(/\,/,"")
    if (pki_type == "max"){
       print kvformat("*" "max-jOPS", $14)
       print kvformat("critical-jOPS", $17)
    } else {
       print kvformat("max-jOPS", $14)
       print kvformat("*" "critical-jOPS", $17)
    }
}
' */output.logs 2>/dev/null || true

#!/usr/bin/gawk

END {
    split(pinst, pinst_fields, ".")
    for (p in svrinfo_values[svrinfo_ws]) {
        for (ip in svrinfo_values[svrinfo_ws][p]) {
            if (svrinfo_values[svrinfo_ws][p][ip]["Host"]["Name"][1] == name) {
                print svrinfo_values[svrinfo_ws][p][ip][pinst_fields[1]][pinst_fields[2]][1]
                break
            }
        }
    }
}


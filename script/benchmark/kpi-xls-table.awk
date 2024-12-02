#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    name="default"
    if (var1 == "default") var1="batch_size"
    if (var2 == "default") var2="cores_per_instance"
    if (var3 == "default") var3=""
    if (var4 == "default") var4=""
    var3v=""
    var4v=""
}

/^#(bom|timestamp|pdu|pcm|uprof|emon|perfspect)[:-] / {
    next
}

/^#sutinfo: / {
    name=gensub("^.*logs-([^/]*)[/].*$","\\1",1,$2)
}

/[/]itr-[0-9]*:$/ {
    name=gensub("^.*logs-([^/]*)[/].*$","\\1",1)
    status="failed"
}

/^# status: (passed|failed)/ {
    status=$3
}

index($0,var1)==1 || ($1=="#" && index($2,var1)==1) {
    var1v=gensub(/"/,"","g",$NF)
}

index($0,var2)==1 || ($1=="#" && index($2,var2)==1) {
    var2v=gensub(/"/,"","g",$NF)
}

(index($0,var3)==1 || ($1=="#" && index($2,var3)==1)) && length(var3)>0 {
    var3v=var3": "gensub(/"/,"","g",$NF)
}

(index($0,var4)==1 || ($1=="#" && index($2,var4)==1)) && length(var4)>0 {
    var4v=var4": "gensub(/"/,"","g",$NF)
}

/^[*].*: *([0-9.-][0-9.e+-]*) *#*.*$/ && status=="passed" {
    primary_kpi[name]=gensub(/^.*: *([0-9.-][0-9.-]*).*$/,"\\1",1,$0)
    var34v=""
    if (length(var3)>0) var34v=var3v
    if (length(var4)>0) {
        if (length(var34v)>0)
            var34v=var34v", "var4v
        else
            var34v=var4v
    }
    idx= ++ikpis[name][var34v][var2v][var1v]
    kpis[name][var34v][var2v][var1v][idx]=$NF
    if (idx > var1v_num[name][var1v])
        var1v_num[name][var1v]=idx
}

END {
    add_xls_header(1)

    for (ws in kpis) {
        ntables=asorti(kpis[ws], tables, "@ind_str_asc")

        print "<Worksheet ss:Name=\"" ws_name(ws) "\">"
        print "<Table>"

        th=3
        var1v_nsp=asorti(var1v_num[ws], var1v_sp, "@ind_num_asc")
        for (v1=1;v1<=var1v_nsp;v1++) {
            ith[v1]=th
            nk=var1v_num[ws][var1v_sp[v1]]
            for (k=1;k<=nk;k++)
               print "<Column ss:Index=\"" (th+k) "\" ss:Hidden=\"1\" ss:AutoFitWidth=\"0\"/>"
            th+=nk+1
        }

        for (t=1;t<=ntables;t++) {
            print "<Row>"
            print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">" tables[t] "</Data></Cell>"
            print "</Row>"
            var34=tables[t]

            print "<Row>"
            print "<Cell ss:Index=\"" ith[1] "\"><Data ss:Type=\"String\">" var1 "</Data></Cell>"
            print "</Row>"

            print "<Row>"
            print "<Cell ss:StyleID=\"border\" ss:Index=\"" ith[1]-1 "\"><Data ss:Type=\"String\">" primary_kpi[ws] "</Data></Cell>"
            for (v1=1;v1<=var1v_nsp;v1++) {
                style=(var1v_sp[v1]==var1v_sp[v1]*1)?"Number":"String"
                print "<Cell ss:StyleID=\"border\" ss:Index=\"" ith[v1] "\"><Data ss:Type=\"" style "\">" var1v_sp[v1] "</Data></Cell>"
            }
            print "</Row>"

            var2v_nsp=asorti(kpis[ws][var34], var2v_sp, "@ind_num_asc")
            for (v2=1;v2<=var2v_nsp;v2++) {
                print "<Row>"
                if (v2==1) {
                    print "<Cell ss:Index=\"" ith[1]-2 "\"><Data ss:Type=\"String\">" var2 "</Data></Cell>"
                }
                style=(var2v_sp[v2]==var2v_sp[v2]*1)?"Number":"String"
                print "<Cell ss:StyleID=\"border\" ss:Index=\"" ith[1]-1 "\"><Data ss:Type=\"" style "\">" var2v_sp[v2] "</Data></Cell>"
                for (v1=1;v1<=var1v_nsp;v1++) {
                    n=length(kpis[ws][var34][var2v_sp[v2]][var1v_sp[v1]])
                    if (n>0) {
                        m=median(kpis[ws][var34][var2v_sp[v2]][var1v_sp[v1]])
                        print "<Cell ss:StyleID=\"border\" ss:Index=\"" ith[v1] "\"><Data ss:Type=\"Number\">" m "</Data></Cell>"
                        for (n1=1;n1<=n;n1++) {
                            n1v=kpis[ws][var34][var2v_sp[v2]][var1v_sp[v1]][n1]
                            style=(m""==n1v"")?"-median":""
                            print "<Cell ss:StyleID=\"border" style "\" ss:Index=\"" ith[v1]+n1 "\"><Data ss:Type=\"Number\">" n1v "</Data></Cell>"
                        }
                    }
                }
                print "</Row>"
            }
            print "<Row>"
            print "</Row>"
        }

        print "</Table>"
        print "</Worksheet>"

        if (length(sutinfo_values[ws])>0) 
            add_sutinfo(ws)
    }
    print "</Workbook>"
}

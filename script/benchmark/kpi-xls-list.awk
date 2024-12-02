#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

/^#(pdu|pcm|uprof|emon|perfspect)[:-] / {
    next
}

/^#sutinfo: / {
    product=$3
}

/^(stack|image|workload)\// {
    status="failed"
}

/^(workload|image|stack)\/.*\/itr-[0-9]*:$/ {
    split($1,columns,"/")
    workload=columns[2]
    testcase=gensub(/^.*[/]([^/]*logs-[^/]*)[/].*$/,"\\1",1)
}

/^# status: (passed|failed)/ {
    status=$3
}

/^[^#].*: *[0-9.-][0-9.e+-]* *#?.*$/ && status=="passed" {
    k=gensub(/^(.*): *[0-9.-]+.*$/, "\\1", 1)
    v=gensub(/^.*: *([0-9.-]+).*/, "\\1", 1)
    if (workload in kpis_u) {
        if (k in kpis_u[workload]) {
            j=kpis_u[workload][k]
        } else {
            kpis_u[workload][k]=j=length(kpis_u[workload])+1
        }
    } else {
        kpis_u[workload][k]=j=1
    }
    kpis_k[workload][j]=k
    kpis_v[workload][testcase][product][j][++kpis_v_ct[workload][testcase][product][j]]=v
}

/^#bom- / && status=="passed" {
    k=gensub(/^#bom- ([a-zA-Z0-9_]*):.*/,"\\1",1)
    v=gensub(/["]/,"","g",gensub(/^#bom- [a-zA-Z0-9_]*: /,"",1))
    while (match(v,/[$][{]([a-zA-Z0-9_]*)[}]/)>0) {
        k1=gensub(/.*[$][{]([a-zA-Z0-9_]*)[}].*/,"\\1",1,v)
        v1=""
        if (length(bom[workload])>0)
          if (length(bom[workload][testcase])>0)
            if (length(bom[workload][testcase][product])>0)
              if (length(bom[workload][testcase][product][k1])>0) 
                v1=bom[workload][testcase][product][k1]
        v=gensub(/.*[$][{][a-zA-Z0-9_]*[}].*/,v1,1,v)
    }
    bom[workload][testcase][product][k]=v
    bom_uniq[workload][k]=1
}

/^# [a-zA-Z0-9_]*:/ && status=="passed" {
    k=gensub(/^# ([a-zA-Z0-9_]*):.*/,"\\1",1)
    v=gensub(/["]/,"","g",gensub(/^# [a-zA-Z0-9_]*: /,"",1))
    if (k!="status" && k!="testcase") {
        tunables[workload][testcase][product][k]=v
        tunables_uniq[workload][k]=1
    }
}

function empty_lines (lines) {
    for(k=1;k<=lines;k++) {
        print "<Row></Row>"
    }
}

END {
    add_xls_header(1)

    nws=asorti(kpis_u, wssp, "@ind_str_asc")
    for (iws=1;iws<=nws;iws++) {
        nk=length(kpis_u[wssp[iws]])

        print "<Worksheet ss:Name=\"" ws_name2(wssp[iws]) "\">"
        print "<Table>"

        th=2
        ntc=asorti(kpis_v[wssp[iws]], tcsp, "@ind_str_asc")
        for (itc=1;itc<=ntc;itc++) {
            npt[itc]=asorti(kpis_v[wssp[iws]][tcsp[itc]], tmp, "@ind_str_asc")
            for (ipt=1;ipt<=npt[itc];ipt++) {
                ptsp[itc][ipt]=tmp[ipt]
                ith[itc][ipt]=th++

                nk1=0
                for (k=1;k<=nk;k++) {
                    nk1n=length(kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k])
                    if (nk1n>nk1) nk1=nk1n
                }
                if (nk1>1)
                    for (k=1;k<=nk1;k++)
                        print "<Column ss:Index=\"" (th++) "\" ss:Hidden=\"1\" ss:AutoFitWidth=\"0\"/>"
            }
            ith[itc][ipt]=th
        }
        
        add_sutinfo_brief(tcsp, ptsp, ith)

        if (length(bom_uniq[wssp[iws]])>0) {
            empty_lines(2)
            nbom=asorti(bom_uniq[wssp[iws]], bomsp, "@ind_str_asc")
            for (ib=1;ib<=nbom;ib++) {
                print "<Row>"
                print "<Cell><Data ss:Type=\"String\">" escape(bomsp[ib]) "</Data></Cell>"
                for (itc=1;itc<=ntc;itc++)
                    for (ipt=1;ipt<=npt[itc];ipt++) {
                        print "<Cell ss:Index=\"" ith[itc][ipt] "\" ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(bom[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][bomsp[ib]]) "</Data></Cell>"
                    }
                print "</Row>"
            }
        }

        if (length(tunables_uniq[wssp[iws]])>0) {
            empty_lines(2)
            ntunables=asorti(tunables_uniq[wssp[iws]], tunablessp, "@ind_str_asc")
            for (itu=1;itu<=ntunables;itu++) {
                print "<Row>"
                print "<Cell><Data ss:Type=\"String\">" escape(tunablessp[itu]) "</Data></Cell>"
                for (itc=1;itc<=ntc;itc++)
                    for (ipt=1;ipt<=npt[itc];ipt++) {
                        print "<Cell ss:Index=\"" ith[itc][ipt] "\" ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(tunables[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][tunablessp[itu]]) "</Data></Cell>"
                    }
                print "</Row>"
            }
        }

        empty_lines(2)

        # calculate median
        split("",kn)
        split("",kii)
        for (itc=1;itc<=ntc;itc++) {
            for (ipt=1;ipt<=npt[itc];ipt++) {
                for(k=1;k<=nk;k++) {
                    kn[itc][ipt][k]=length(kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k])
                    kii[itc][ipt][k]=0
                    if (kn[itc][ipt][k]>0) {
                        m=median(kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k])
                        for (i=1;i<=kn[itc][ipt][k];i++)
                            if (m==kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k][i]) 
                                kii[itc][ipt][k]=i
                    }
                }
            }
        }
            
        # kpis
        for(k=1;k<=nk;k++) {
            print "<Row>"
            print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(kpis_k[wssp[iws]][k]) "</Data></Cell>"
            for (itc=1;itc<=ntc;itc++) {
                for(ipt=1;ipt<=npt[itc];ipt++) {
                    if (length(kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k])>0) {
                        print "<Cell ss:Index=\"" ith[itc][ipt] "\" ss:StyleID=\"border\"><Data ss:Type=\"Number\">" kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k][kii[itc][ipt][k]]*1 "</Data></Cell>"
                    } else {
                        print "<Cell ss:Index=\"" ith[itc][ipt] "\" ss:StyleID=\"border\"><Data ss:Type=\"Number\"></Data></Cell>"
                    }
                    if (kn[itc][ipt][k]>1) {
                        for(i=1;i<=kn[itc][ipt][k];i++) {
                            style=(i==kii[itc][ipt][k])?"-median":""
                            if (length(kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k])>0) {
                                print "<Cell ss:StyleID=\"border" style "\"><Data ss:Type=\"Number\">" kpis_v[wssp[iws]][tcsp[itc]][ptsp[itc][ipt]][k][i]*1 "</Data></Cell>"
                            } else {
                                print "<Cell ss:StyleID=\"border" style "\"><Data ss:Type=\"Number\"></Data></Cell>"
                            }
                        }
                    }
                }
            }
            print "</Row>"
        }

        print "</Table>"
        print "</Worksheet>"
    }
    if (nws<1)
        print "<Worksheet ss:Name=\"Sheet1\"></Worksheet>"
    print "</Workbook>"
}

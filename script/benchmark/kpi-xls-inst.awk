#!/usr/bin/gawk

/^#svrinfo: / {
    name=gensub(/^.*logs-([^/]*)[/].*$/,"\\1",1,$2)
    product=$3
}

/\/itr-[0-9]*:$/ {
    name=gensub(/^.*logs-([^/]*)[/].*$/,"\\1",1)
}

(!/^#/) && /.*: *[0-9.-]+ *$/ {
    k=gensub(/^(.*):.*$/, "\\1", 1)
    v=gensub(/^.*: *([0-9.-]+) *$/, "\\1", 1)
    kpis[name][product][k][++kpisct[name][product][k]]=v
    kpis_uniq[name][k]=1
}

END {
    add_xls_header(1)

    for (ws in kpis) {
        nk=asorti(kpis_uniq[ws], ksp, "@ind_str_asc")
        if(nk>24) nk=24
        np=asorti(kpis[ws], psp, "@ind_str_asc")

        print "<Worksheet ss:Name=\"" ws_name(ws) "\">"
        print "<Table>"

        th=2
        for (p=1;p<=np;p++) {
            ith[p]=th
            nk1=0
            for (k=1;k<=nk;k++) {
                nk1n=length(kpis[ws][psp[p]][ksp[k]])
                if (nk1n>nk1) nk1=nk1n
            }
            for (k=1;k<=nk1;k++)
                print "<Column ss:Index=\"" (th+k) "\" ss:Hidden=\"1\" ss:AutoFitWidth=\"0\"/>"
            
            th+=nk1+1
        }
        ith[p]=th
        
        print "<Row>"
        print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">Instance Type</Data></Cell>"
        for (p=1;p<=np;p++) {
            print "<Cell ss:Index=\"" ith[p] "\" ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(psp[p]) "</Data></Cell>"
        }
        print "</Row>"

        # calculate median
        for (p=1;p<=np;p++) {
            kn[p]=length(kpis[ws][psp[p]][ksp[1]])
            m=median(kpis[ws][psp[p]][ksp[1]])
            kii[p]=0
            for (i=1;i<=kn[p];i++)
                if (m==kpis[ws][psp[p]][ksp[1]][i]) 
                    kii[p]=i
        }
            
        # kpis
        for(k=1;k<=nk;k++) {
            print "<Row>"
            print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(ksp[k]) "</Data></Cell>"
            for(p=1;p<=np;p++) {
                print "<Cell ss:Index=\"" ith[p] "\" ss:StyleID=\"border\"><Data ss:Type=\"Number\">" kpis[ws][psp[p]][ksp[k]][kii[p]]*1 "</Data></Cell>"
                for(i=1;i<=kn[p];i++) {
                    style=(i==kii[p])?"-median":""
                    print "<Cell ss:StyleID=\"border" style "\"><Data ss:Type=\"Number\">" kpis[ws][psp[p]][ksp[k]][i]*1 "</Data></Cell>"
                }
            }
            print "</Row>"
        }

        # empty KPI lines
        for(k=nk+1;k<=23;k++) {
            print "<Row>"
            print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\"></Data></Cell>"
            for(p=1;p<=np;p++) {
                print "<Cell ss:Index=\"" ith[p] "\" ss:StyleID=\"border\"><Data ss:Type=\"String\"></Data></Cell>"
                for(i=1;i<=kn[p];i++)
                    print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\"></Data></Cell>"
            }
            print "</Row>"
        }

        add_svrinfo_ex(ws, psp, ith)

        print "</Table>"
        print "</Worksheet>"

        add_svrinfo(ws)
    }
    print "</Workbook>"
}

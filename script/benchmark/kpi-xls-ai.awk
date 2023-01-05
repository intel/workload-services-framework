#!/usr/bin/gawk

BEGIN {
    if (var1 == "default") var1="BATCH_SIZE"
    if (var2 == "default") var2="CORES_PER_INSTANCE"
    if (var3 == "default") var3="*Throughput"
    if (var4 == "default") var4="Throughput_"
}

function get_value() {
    if ($NF*1 == $NF) return $NF
    if ($(NF-1)*1 == $(NF-1)) return $(NF-1)
    print "Unable to extract value: "$0 > "/dev/stderr"
    exit 3
}

/^#svrinfo: / {
    product=$3
}

/\/itr-[0-9]*:$/{
    name=gensub(/^.*logs-([^/]*)[/].*$/,"\\1",1)
    itr=gensub(/^.*[/]itr-([0-9]+):$/,"\\1",1)
}

index($0,var1)==1 || ($1=="#" && index($2,var1)==1) {
    var1v=gensub(/"(.*)"/,"\\1",1,$NF)
}

index($0,var2)==1 || ($1=="#" && index($2,var2)==1) {
    var2v=gensub(/"(.*)"/,"\\1",1,$NF)
}

index($0,var3)==1 {
    var3v[name][product][var1v][var2v][++var3vct[name][product][var1v][var2v]]=get_value()
    n=length(var3v[name][product][var1v][var2v])
    if (n>var34n[name][product][var1v][var2v])
        var34n[name][product][var1v][var2v]=n
}

index($0,var4)==1 {
    idx=gensub(/ *([0-9]+).*$/,"\\1",1,substr($0,length(var4)+1))
    var4v[name][product][var1v][var2v][idx][++var4vct[name][product][var1v][var2v][idx]]=get_value()
    n=length(var4v[name][product][var1v][var2v][idx])
    if (n>var34n[name][product][var1v][var2v])
        var34n[name][product][var1v][var2v]=n
}

END {
    add_xls_header()

    print "<Worksheet ss:Name=\"Summary\">"
    print "<Table>"

    print "<Row>"
    print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(var1) "</Data></Cell>"
    for (ws in var3v) {
        for (p in var3v[ws]) {
            ws_p=ws"-"p
            print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(ws_name_ex(ws_p)) "</Data></Cell>"
            for (v1 in var3v[ws][p]) {
                v1s[v1][ws_p]=0
                for (v2 in var3v[ws][p][v1]) {
                    var3m=length(var3v[ws][p][v1][v2])>0?median(var3v[ws][p][v1][v2]):0 
                    if (var3m>v1s[v1][ws_p]) v1s[v1][ws_p]=var3m
                }
            }
        }
    }
    print "</Row>"

    n1=asorti(v1s,v1sp,"@ind_num_asc")
    for (v1=1;v1<=n1;v1++) {
        print "<Row>"
        print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"Number\">" v1sp[v1]*1 "</Data></Cell>"
        for (ws in var3v) {
            for (p in var3v[ws]) {
                print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"Number\">" v1s[v1sp[v1]][ws"-"p]*1 "</Data></Cell>"
            }
        }
        print "</Row>"
    }
    print "</Table>"
    print "</Worksheet>"

    for (ws in var34n) {
        for (p in var34n[ws]) {
            print "<Worksheet ss:Name=\"" ws_name(ws"-"p) "\">"
            print "<Table>"
            n1=asorti(var34n[ws][p], var1sp, "@ind_num_asc")

            th=1
            for(v1=1;v1<=n1;v1++) {
                th++
                n2=asorti(var34n[ws][p][var1sp[v1]], var2sp, "@ind_num_asc")
                for (v2=1;v2<=n2;v2++) {
                    th++
                    n3=var34n[ws][p][var1sp[v1]][var2sp[v2]]
                    for (i=1;i<=n3;i++) {
                        print "<Column ss:Index=\"" th "\" ss:Hidden=\"1\" ss:AutoFitWidth=\"0\"/>"
                        th++
                    }
                }
                th++
            }

            th=1
            print "<Row>"
            for (v1=1;v1<=n1;v1++) {
                print "<Cell ss:Index=\"" th "\"><Data ss:Type=\"String\">" escape(var1) "</Data></Cell>"
                print "<Cell><Data ss:Type=\"Number\">" var1sp[v1]*1 "</Data></Cell>"
                th++

                for (v2 in var34n[ws][p][var1sp[v1]])
                    th+=var34n[ws][p][var1sp[v1]][v2]+1
                th++
            }
            print "</Row>"

            print "<Row>"
            th=1
            for(v1=1;v1<=n1;v1++) {
                print "<Cell ss:StyleID=\"border\" ss:Index=\"" th "\"><Data ss:Type=\"String\">" escape(var2) "</Data></Cell>"
                th++

                n2=asorti(var34n[ws][p][var1sp[v1]], var2sp, "@ind_num_asc")
                for (v2=1;v2<=n2;v2++) {
                    print "<Cell ss:StyleID=\"border\" ss:Index=\"" th "\"><Data ss:Type=\"Number\">" var2sp[v2]*1 "</Data></Cell>"
                    th+=var34n[ws][p][var1sp[v1]][var2sp[v2]]+1
                }
                th++
            }
            print "</Row>"

            print "<Row>"
            th=1
            for(v1=1;v1<=n1;v1++) {
                print "<Cell ss:StyleID=\"border-primary\" ss:Index=\"" th "\"><Data ss:Type=\"String\">" escape(gensub(/^\*/,"",1,var3)) "</Data></Cell>"
                th++

                n2=asorti(var34n[ws][p][var1sp[v1]], var2sp, "@ind_num_asc")
                for (v2=1;v2<=n2;v2++) {
                    var3m=length(var3v[ws][p][var1sp[v1]][var2sp[v2]])>0?median(var3v[ws][p][var1sp[v1]][var2sp[v2]]):0
                    print "<Cell ss:StyleID=\"border-primary\"><Data ss:Type=\"Number\">" var3m*1 "</Data></Cell>"
                    th++

                    n3=var34n[ws][p][var1sp[v1]][var2sp[v2]]
                    for (i=1;i<=n3;i++) {
                        vi=(length(var3v[ws][p][var1sp[v1]][var2sp[v2]])>0)?var3v[ws][p][var1sp[v1]][var2sp[v2]][i]:0
                        if (vi==var3m) {
                            print "<Cell ss:StyleID=\"border-median-primary\"><Data ss:Type=\"Number\">" var3m*1 "</Data></Cell>"
                            var4i[ws][var1sp[v1]][var2sp[v2]]=i
                        } else {
                            print "<Cell ss:StyleID=\"border-primary\"><Data ss:Type=\"Number\">" vi*1 "</Data></Cell>"
                        }
                        th++
                    }
                }
                th++
            }
            print "</Row>"

            print "<Row>"
            th=1
            cn=0
            for(v1=1;v1<=n1;v1++) {
                print "<Cell ss:StyleID=\"border\" ss:Index=\"" th "\"><Data ss:Type=\"String\">count</Data></Cell>"
                th++

                n2=asorti(var34n[ws][p][var1sp[v1]], var2sp, "@ind_num_asc")
                for (v2=1;v2<=n2;v2++) {
                    count=length(var4v[ws][p][var1sp[v1]][var2sp[v2]])
                    print "<Cell ss:StyleID=\"border\" ss:Index=\"" th "\"><Data ss:Type=\"Number\">" count*1 "</Data></Cell>"
                    if (count>cn) cn=count
                    th+=var34n[ws][p][var1sp[v1]][var2sp[v2]]+1
                }
                th++
            }
            print "</Row>"

            for (c=1;c<=cn;c++) {
                print "<Row>"

                th=2
                for(v1=1;v1<=n1;v1++) {
                    n2=asorti(var34n[ws][p][var1sp[v1]], var2sp, "@ind_num_asc")
                    for (v2=1;v2<=n2;v2++) {
                        n4=var34n[ws][p][var1sp[v1]][var2sp[v2]]
                        if (length(var4v[ws][p][var1sp[v1]][var2sp[v2]][c])>0) {
                            var4ii=var4i[ws][var1sp[v1]][var2sp[v2]]
                            print "<Cell ss:Index=\"" th "\"><Data ss:Type=\"Number\">" var4v[ws][p][var1sp[v1]][var2sp[v2]][c][var4ii]*1 "</Data></Cell>"

                            for(i=1;i<=n4;i++) {
                                if (i==var4ii) {
                                    print "<Cell ss:StyleID=\"border-median\"><Data ss:Type=\"Number\">" var4v[ws][p][var1sp[v1]][var2sp[v2]][c][i]*1 "</Data></Cell>"
                                } else {
                                    print "<Cell><Data ss:Type=\"Number\">" var4v[ws][p][var1sp[v1]][var2sp[v2]][c][i]*1 "</Data></Cell>"
                                }
                            }
                        } 
                        th+=n4+1
                    }
                    th+=2
                }
                print "</Row>"
            }

            print "</Table>"
            print "</Worksheet>"
        }

        # write svrinfo
        if (length(svrinfo_values[ws])>0) 
            add_svrinfo(ws)
    }
    print "</Workbook>"
}

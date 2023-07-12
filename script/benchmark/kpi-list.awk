#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

/^#svrinfo[:-] / {
    if (!svrinfo) next
}
/^#inventory- / || /^#config- / {
    next
}
{   
    print $0
}
/^*/ {
    kpi=$NF
    $NF=""
    n[$0]=n[$0]+1
    kpis[$0][n[$0]]=kpi
}
END {
    print ""
    for (x in n) {
        sum[x]=0
        sumsq[x]=0
        for (y in kpis[x]) {
            sum[x]+=kpis[x][y]
            sumsq[x]+=kpis[x][y]^2
        }
        average=sum[x]/n[x]
        stdev=sqrt((sumsq[x]-sum[x]^2/n[x])/n[x])

        print "avg "x,average
        print "std "x,stdev

        average=sum[x]/n[x]
        stdev=sqrt((sumsq[x]-sum[x]^2/n[x])/n[x])

        asort(kpis[x], kpis1, "@val_num_asc")
        if(n[x]%2) {
            k=(n[x]+1)/2
            print "med "x,kpis1[k]
        } else {
            k=n[x]/2+1
            print "med "x,kpis1[k]
        }

        r=0
        if (outlier>0) {
            for (y in kpis[x]) {
                if ((kpis[x][y]>average+outlier*stdev)||(kpis[x][y]<average-outlier*stdev)) {
                    delete kpis[x][y];
                    r=r+1
                }
            }
        }

        if (r>0) {
            print "removed "r" outlier(s)"

            sum[x]=0
            sumsq[x]=0
            n[x]=0
            for (y in kpis[x]) {
                sum[x]+=kpis[x][y]
                sumsq[x]+=kpis[x][y]^2
                n[x]=n[x]+1
            }

            asort(kpis[x], kpis1, "@val_num_asc")
            if(n[x]%2) {
                k=(n[x]+1)/2
                print "med "x,kpis1[k]
            } else {
                k=n[x]/2+1
                print "med "x,kpis1[k]
            }

            average=sum[x]/n[x]
            stdev=sqrt((sumsq[x]-sum[x]^2/n[x])/n[x])
            print "avg "x,average
            print "std "x,stdev
        }
    }
}

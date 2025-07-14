#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    status="failed"
}

/^#(pcm|pdu|uprof|emon|perfspect|turbostat): / {
    nc=split($2,columns,"/")
    for(i=3;i<=nc-1;i++)
      if(columns[i]~/logs-/)break
    split(columns[i+1],fields,"-")
    pwr_host=fields[1]"-"fields[2]
    pwr_itr=fields[3]
    detected_profile_records=0
    detected_record_id=0
}
/^#(pcm|uprof|perfspect): / {
    pwr_roi=columns[i+2]
}
/^#(pdu|emon|turbostat): / {
    patsplit(columns[i+2],fields,/[0-9][0-9]*/)
    pwr_roi="roi-"fields[1]
}
/^#pcm- S[0-9]*; Consumed energy units:/ {
    socket=gensub(/S([0-9]*);/,"\\1",1,$2)
    pcm_data[pwr_host][pwr_roi][++pcm_count[pwr_host][pwr_roi][socket]]+=gensub(/;/,"","g",$11)*1
}
/^#pdu- [0-9][0-9]*,[0-9][0-9.]*/ {
    split($0,tp,",")
    pdu_data[pwr_host][pwr_roi][++pwr_count[pwr_host][pwr_roi]]=tp[2]
}
/^#uprof- PROFILE RECORDS/ && !detected_profile_records {
    detected_profile_records=1
    split("",uprof_sockets)
}
/^#uprof- .*,.*/ && detected_profile_records && detected_record_id && length(uprof_sockets)>0 {
    split($0,fields,",")
    p=0
    for (s in uprof_sockets)
        p+=fields[uprof_sockets[s]]
    if (p>0) uprof_data[pwr_host][pwr_roi][++uprof_count[pwr_host][pwr_roi]]+=p
}
/^#uprof- RecordId,/ && detected_profile_records && !detected_record_id {
    split($0,fields,",")
    socket_count=0
    for (i in fields) {
        if (fields[i] ~ /^socket[0-9][0-9]*-package-power$/)
            uprof_sockets[++socket_count]=i
    }
    detected_record_id=1
}
/^#emon- [0-9]*,/ && length(emon_sockets)>0 {
    split($0,fields,",")
    p=0
    for (s in emon_sockets)
        p+=fields[emon_sockets[s]]
    if (p>0) emon_data[pwr_host][pwr_roi][++emon_count[pwr_host][pwr_roi]]+=p
}
/^#emon- #sample/ {
    split($0,fields,",")
    socket_count=0
    for (i in fields) {
        if (fields[i] ~ /metric_package power/) 
            emon_sockets[++socket_count]=i
    }
}
/^#perfspect- .*,package power [(]watts[)],/ {
    split($0,fields,",")
    for (i in fields)
        if (fields[i] == "package power (watts)")
            perfspect_package_power_column=i
    next
}
/^#perfspect- / {
    split($0,fields,",")
    perfspect_data[pwr_host][pwr_roi][++perfspect_count[pwr_host][pwr_roi]]+=fields[perfspect_package_power_column]
}
/^#turbostat- / && /Time_Of_Day_Seconds/ {
    for (i=2;i<=NF;i++)
      turbostat_columns[$i]=i
}
/^#turbostat- / && $(turbostat_columns["Core"])=="-" && $(turbostat_columns["CPU"])=="-" {
    turbostat_pkgwatt_data[pwr_host][pwr_roi][++turbostat_count[pwr_host][pwr_roi]]+=$(turbostat_columns["PkgWatt"])*1
    turbostat_corwatt_data[pwr_host][pwr_roi][turbostat_count[pwr_host][pwr_roi]]+=$(turbostat_columns["CorWatt"])*1
    turbostat_gfxwatt_data[pwr_host][pwr_roi][turbostat_count[pwr_host][pwr_roi]]+=$(turbostat_columns["GFXWatt"])*1
    turbostat_ramwatt_data[pwr_host][pwr_roi][turbostat_count[pwr_host][pwr_roi]]+=$(turbostat_columns["RAMWatt"])*1
}
/^#(bom|timestamp|pdu|pcm|uprof|emon|perfspect|sar|collectd|igt|turbostat|sutinfo|logsdir|terraform-config|.*[.]csv)[:-] / {
    if (!sutinfo) next
}
{ 
    print $0
}
/^# status: (passed|failed)/ {
    status=$3
}
/^[*].*: *([0-9.-][0-9.e+-]*) *#*.*$/ && status=="passed" {
    k=gensub(/^(.*): *[0-9.-][0-9.-]*.*$/,"\\1",1,$0)
    v=gensub(/^.*: *([0-9.-][0-9.-]*).*$/,"\\1",1,$0)
    if (k in kpis_u) {
        j=kpis_u[k]
    } else {
        j=length(kpis_u)+1
        kpis_u[k]=j
    }
    kpis_k[j]=k
    kpis_v[j][++kpis_vct[j]]=v
}
END {
    print ""
    nk=length(kpis_k)
    for (x=1;x<=nk;x++) {
        sum[x]=0
        sumsq[x]=0
        for (y in kpis_v[x]) {
            sum[x]+=kpis_v[x][y]
            sumsq[x]+=kpis_v[x][y]^2
        }
        nv[x]=length(kpis_v[x])
        average=sum[x]/nv[x]
        stdev=sqrt((sumsq[x]-sum[x]^2/nv[x])/nv[x])

        print "avg "kpis_k[x]": "average
        print "std "kpis_k[x]": "stdev

        average=sum[x]/nv[x]
        stdev=sqrt((sumsq[x]-sum[x]^2/nv[x])/nv[x])

        asort(kpis_v[x], kpis1, "@val_num_asc")
        if(nv[x]%2) {
            k=(nv[x]+1)/2
            print "med "kpis_k[x]": "kpis1[k]
        } else {
            k=nv[x]/2+1
            print "med "kpis_k[x]": "kpis1[k]
        }

        geo_sum = 0
        for (y in kpis_v[x]) {
            log_value = log(kpis_v[x][y])
            geo_sum += log_value
        }
        geo_avg = exp(geo_sum / nv[x])
        print "geo "kpis_k[x]": " geo_avg
    }
    if (length(pcm_data)>0) {
        print "pcm socket power (w): "
        for (h in pcm_data) {
            for (r in pcm_data[h])
                print "  "h" "r" avg "calc_avg(pcm_data[h][r])" max "calc_max(pcm_data[h][r])" med "calc_median(pcm_data[h][r])
        }
    }
    if (length(pdu_data)>0) {
        print "pdu power (w): "
        for (h in pdu_data) {
            for (r in pdu_data[h])
                print "  "h" "r" avg "calc_avg(pdu_data[h][r])" max "calc_max(pdu_data[h][r])" med "calc_median(pdu_data[h][r])
        }
    }
    if (length(uprof_data)>0) {
        print "uprof socket packet power (w): "
        for (h in uprof_data) {
            for (r in uprof_data[h])
                print "  "h" "r" avg "calc_avg(uprof_data[h][r])" max "calc_max(uprof_data[h][r])" med "calc_median(uprof_data[h][r])
        }
    }
    if (length(emon_data)>0) {
        print "emon packet power (w): "
        for (h in emon_data) {
            for (r in emon_data[h])
                print "  "h" "r" avg "calc_avg(emon_data[h][r])" max "calc_max(emon_data[h][r])" med "calc_median(emon_data[h][r])
        }
    }
    if (length(perfspect_data)>0) {
        print "perfspect packet power (w): "
        for (h in perfspect_data) {
            for (r in perfspect_data[h])
                print "  "h" "r" avg "calc_avg(perfspect_data[h][r])" max "calc_max(perfspect_data[h][r])" med "calc_median(perfspect_data[h][r])
        }
    }
    if (length(turbostat_pkgwatt_data)>0) {
        print "turbostat packet power (w): "
        for (h in turbostat_pkgwatt_data) {
            for (r in turbostat_pkgwatt_data[h])
                print "  "h" "r" avg "calc_avg(turbostat_pkgwatt_data[h][r])" max "calc_max(turbostat_pkgwatt_data[h][r])" med "calc_median(turbostat_pkgwatt_data[h][r])
        }
    }
    if (length(turbostat_gfxwatt_data)>0) {
        print "turbostat graphics power (w): "
        for (h in turbostat_gfxwatt_data) {
            for (r in turbostat_gfxwatt_data[h])
                print "  "h" "r" avg "calc_avg(turbostat_gfxwatt_data[h][r])" max "calc_max(turbostat_gfxwatt_data[h][r])" med "calc_median(turbostat_gfxwatt_data[h][r])
        }
    }
    if (length(turbostat_corwatt_data)>0) {
        print "turbostat core power (w): "
        for (h in turbostat_corwatt_data) {
            for (r in turbostat_corwatt_data[h])
                print "  "h" "r" avg "calc_avg(turbostat_corwatt_data[h][r])" max "calc_max(turbostat_corwatt_data[h][r])" med "calc_median(turbostat_corwatt_data[h][r])
        }
    }
    if (length(turbostat_ramwatt_data)>0) {
        print "turbostat RAM power (w): "
        for (h in turbostat_ramwatt_data) {
            for (r in turbostat_ramwatt_data[h])
                print "  "h" "r" avg "calc_avg(turbostat_ramwatt_data[h][r])" max "calc_max(turbostat_ramwatt_data[h][r])" med "calc_median(turbostat_ramwatt_data[h][r])
        }
    }
}

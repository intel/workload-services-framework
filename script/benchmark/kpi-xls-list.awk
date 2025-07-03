#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

/^#logsdir: / {
    workload="default"
    testcase="default"
    status="failed"
}

/^(workload|image|stack)\/.*\/itr-[0-9]*:$/ {
    nc=split($1,columns,"/")
    workload=columns[2]
    for (i=3;i<=nc-1;i++)
      if (columns[i]~/logs-/) break
    testcase=columns[i]
    iteration=gensub(/itr-([0-9]*):/,"\\1",1,columns[i+1])*1
    print testcase > "/dev/stderr"

    portal_null[testcase]=""
    logs[workload][testcase]["location"][1]=testcase
}

/^# status: (passed|failed)/ {
    status=$3
}

/^[^#].*: *[0-9.-][0-9.e+-]* *#?.*$/ && status=="passed" {
    k=gensub(/^(.*): *[0-9.-]+.*$/, "\\1", 1)
    v=gensub(/^.*: *([0-9.-]+).*/, "\\1", 1)
    kk=add_prefix(k, kpis_uniq, workload)
    kpis_v[workload][testcase][kk][iteration]=v
}

/^#bom- / && status=="passed" {
    k=gensub(/^#bom- ([a-zA-Z0-9_]*):.*/,"\\1",1)
    v=gensub(/["]/,"","g",gensub(/^#bom- [a-zA-Z0-9_]*: /,"",1))
    while (match(v,/[$][{]([a-zA-Z0-9_]*)[}]/)>0) {
        k1=gensub(/.*[$][{]([a-zA-Z0-9_]*)[}].*/,"\\1",1,v)
        v1=""
        if (length(bom[workload])>0)
          if (length(bom[workload][testcase])>0)
            if (length(bom[workload][testcase])>0)
              if (length(bom[workload][testcase][k1])>0)
                v1=bom[workload][testcase][k1]
        v=gensub(/.*[$][{][a-zA-Z0-9_]*[}].*/,v1,1,v)
    }
    kk=add_prefix(k,bom_uniq,workload)
    bom[workload][testcase][kk][1]=v
}

/^# [a-zA-Z0-9_ \(\)]*:/ && status=="passed" {
    k=gensub(/^# ([a-zA-Z0-9_ \(\)]*):.*/,"\\1",1)
    v=gensub(/["]/,"","g",gensub(/^# [a-zA-Z0-9_]*: /,"",1))
    if (k!="status" && k!="portal" && k!="testcase") {
        kk=add_prefix(k,tunables_uniq,workload)
        tunables[workload][testcase][kk][1]=v
    }
}

/^# portal: / && status=="passed" {
    portal[workload][testcase]=$3
}

/^#terraform-config: / {
    nc=split($2,columns,"/")
    tc_workload=columns[2]
    for(i=3;i<=nc;i++)
      if(columns[i]~/logs-/) break
    tc_testcase=columns[i]
}

/^#terraform-config- variable *"worker_profile" *{/ {
    worker_profile_config[tc_workload][tc_testcase]=1
}
/^#terraform-config-  *} *$/ {
    worker_profile_config[tc_workload][tc_testcase]=0
}
/^#terraform-config-  *instance_type *= *".*"/ && worker_profile_config[tc_workload][tc_testcase]==1 {
    split($0,columns,"\"")
    instance_type[tc_workload][tc_testcase]=columns[2]
}
/^#terraform-config-  *cpu_core_count *= */ && worker_profile_config[tc_workload][tc_testcase]==1 {
    split($0,columns,"=")
    cpu_core_count[tc_workload][tc_testcase]=columns[2]*1
}
/^#terraform-config-  *memory_size *= */ && worker_profile_config[tc_workload][tc_testcase]==1 {
    split($0,columns,"=")
    memory_size[tc_workload][tc_testcase]=columns[2]*1
}
/^#terraform-config- *csp *= *".*",* *$/ {
    split($0,columns,"\"")
    csp[tc_workload][tc_testcase]=columns[2]
    if (columns[2] ~ /kvm|hyperv/)
        instance_type[tc_workload][tc_testcase]="c"cpu_core_count[tc_workload][tc_testcase]"m"memory_size[tc_workload][tc_testcase]
}

/^#(pcm|pdu|uprof|emon|perfspect|sar|collectd|igt|turbostat): / {
    trace_file=$2
    nc=split($2,columns,"/")
    for(i=3;i<=nc-1;i++)
      if(columns[i]~/logs-/)break
    trace_tc=columns[i]
    split(columns[i+1],fields,"-")
    trace_host=fields[1]"-"fields[2]
    trace_itr=fields[3]
    detected_profile_records=0
    detected_record_id=0
    trace_roi="*"
}
/^#(pcm|uprof|perfspect): / {
    trace_roi=columns[i+2]
}
/^#(pdu|emon|turbostat): / {
    patsplit(columns[i+2],fields,/[0-9][0-9]*/)
    trace_roi="roi-"fields[1]
}
/^#sar: / {
    trace_roi="roi-"gensub(/^.*sar-([0-9]*)[.]logs[.]txt$/,"\\1",1,$2)
}
/^#igt: / {
    split(columns[i+2],fields,"-")
    trace_roi="roi-"gensub(/.logs/,"",1,fields[3])
    igt_card=fields[2]
    igt_layer=0
}
/^#pcm- S[0-9][0-9]*; Consumed energy units:/ {
    socket=gensub(/S([0-9]*);/,"\\1",1,$2)
    pcm_power[trace_tc][trace_host"/"trace_roi][trace_itr][++pcm_count[trace_tc][trace_host"/"trace_roi][trace_itr][socket]]+=gensub(/;/,"","g",$11)*1
}
/^#pdu- [0-9][0-9]*,[0-9][0-9.]*/ {
    split($0,tp,",")
    pdu_power[trace_tc][trace_host"/"trace_roi][trace_itr][++pdu_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=tp[2]
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
    if (p>0)
        uprof_power[trace_tc][trace_host"/"trace_roi][trace_itr][++uprof_count[trace_tc][trace_host"/"trace_roi][trace_itr]]+=p
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
/^#emon- [0-9][0-9]*,/ && length(emon_sockets)>0 && (trace_file~/socket_view/) {
    split($0,fields,",")
    p=0
    for (s in emon_sockets)
        p+=fields[emon_sockets[s]]
    if (p>0)
        emon_power[trace_tc][trace_host"/"trace_roi][trace_itr][++emon_socket_count[trace_tc][trace_host"/"trace_roi][trace_itr]]+=p
}
/^#emon- #sample/ && (trace_file~/socket_view/) {
    split($0,fields,",")
    socket_count=0
    for (i in fields) {
        if (fields[i] ~ /metric_package power/)
            emon_sockets[++socket_count]=i
    }
}
/^#emon- [0-9][0-9]*,/ && (trace_file~/system_view/) {
    split($0,fields,",")
    emon_cpu_util[trace_tc][trace_host"/"trace_roi][trace_itr][++emon_system_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=fields[emon_cpu_util_column]*1
}
/^#emon- #sample/ && (trace_file~/system_view/) {
    split($0,fields,",")
    for (i in fields)
        if (fields[i] == "metric_CPU utilization %")
            emon_cpu_util_column=i
}
/^#perfspect- .*,package power [(]watts[)],/ {
    split($0,fields,",")
    for (i in fields) {
        if (fields[i] == "package power (watts)")
            perfspect_package_power_column=i
        if (fields[i] == "CPU utilization %")
            perfspect_cpu_util_column=i
    }
    next
}
/^#perfspect- / {
    split($0,fields,",")
    perfspect_power[trace_tc][trace_host"/"trace_roi][trace_itr][++perfspect_count[trace_tc][trace_host"/"trace_roi][trace_itr]]+=fields[perfspect_package_power_column]
    perfspect_cpu_util[trace_tc][trace_host"/"trace_roi][trace_itr][perfspect_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=fields[perfspect_cpu_util_column]
}
/^#sar- *$/ {
    sar_section=""
}
/^#sar- [0-9:][0-9:]*  *CPU  *%usr / {
    sar_section="CPU"
}
/^#sar- [0-9:][0-9:]*  *all / && sar_section=="CPU" {
    sar_cpu_util[trace_tc][trace_host"/"trace_roi][trace_itr][++sar_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=$4*1
}
/^#collectd- [0-9][0-9.]*,[0-9.e+-][0-9.e+-]*/ {
    split($2,fields,",")
    collectd_cpu_util[trace_tc][trace_host"/"trace_roi][trace_itr][++collectd_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=fields[2]*1
}
/^#igt- .*[{]/ {
    igt_layer++
}
/^#igt- .*[}]/ {
    igt_layer--
}
/^#igt- / && $3=="{" {
    igt_section[igt_layer]=gensub(/\/[0-9]*$/,"",1,gensub(/[":]/,"","g",$2))
    igt_component=($2 ~ /\/[0-9]*"/)?gensub(/^.*\/([0-9]*)".*$/,"\\1",1,$2)*1:0
    if (igt_component == 0)
      igt_section_count[igt_section[igt_layer]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]++
}
/^#igt- / && igt_section[2]=="power" && $2=="\"Package\":" {
    igt_package_power[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[2]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]=gensub(/,/,"",1,$3)*1
}
/^#igt- / && igt_section[2]=="engines" && igt_section[3]=="Render/3D" && $2=="\"busy\":" {
    igt_render3d_busy[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[3]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]+=gensub(/,/,"",1,$3)*1
}
/^#igt- / && igt_section[2]=="engines" && igt_section[3]=="Blitter" && $2=="\"busy\":" {
    igt_blitter_busy[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[3]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]+=gensub(/,/,"",1,$3)*1
}
/^#igt- / && igt_section[2]=="engines" && igt_section[3]=="Video" && $2=="\"busy\":" {
    igt_video_busy[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[3]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]+=gensub(/,/,"",1,$3)*1
}
/^#igt- / && igt_section[2]=="engines" && igt_section[3]=="VideoEnhance" && $2=="\"busy\":" {
    igt_video_enhance_busy[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[3]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]+=gensub(/,/,"",1,$3)*1
}
/^#igt- / && igt_section[2]=="engines" && igt_section[3]=="Compute" && $2=="\"busy\":" {
    igt_compute_busy[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[3]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]+=gensub(/,/,"",1,$3)*1
}
/^#igt- / && igt_section[2]=="engines" && igt_section[3]=="[unknown]" && $2=="\"busy\":" {
    igt_unknown_busy[trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr][igt_section_count[igt_section[3]][trace_tc][trace_host"/"igt_card"/"trace_roi][trace_itr]]+=gensub(/,/,"",1,$3)*1
}
/^#turbostat- / && /Time_Of_Day_Seconds/ {
    for (i=2;i<=NF;i++)
      turbostat_columns[$i]=i
}
/^#turbostat- / && $(turbostat_columns["Core"])=="-" && $(turbostat_columns["CPU"])=="-" {
    turbostat_pkgwatt[trace_tc][trace_host"/"trace_roi][trace_itr][++turbostat_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=$(turbostat_columns["PkgWatt"])*1
    turbostat_gfxwatt[trace_tc][trace_host"/"trace_roi][trace_itr][turbostat_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=$(turbostat_columns["GFXWatt"])*1
    turbostat_corwatt[trace_tc][trace_host"/"trace_roi][trace_itr][turbostat_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=$(turbostat_columns["CorWatt"])*1
    turbostat_ramwatt[trace_tc][trace_host"/"trace_roi][trace_itr][turbostat_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=$(turbostat_columns["RAMWatt"])*1
    turbostat_busy[trace_tc][trace_host"/"trace_roi][trace_itr][turbostat_count[trace_tc][trace_host"/"trace_roi][trace_itr]]=$(turbostat_columns["Busy%"])*1
}

function empty_lines (lines) {
    for(k=1;k<=lines;k++) {
        print "<Row></Row>"
    }
}

function has_data(data, workload, tcsp    ,itc,ntc) {
    ntc=length(tcsp)
    if (length(data[workload])>0)
        for (itc=1;itc<=ntc;itc++)
            if (length(data[workload][tcsp[itc]])>0)
                return 1
    return 0
}

# sort by prioritizing worker-0
function host_compare(ia,va,ib,vb) {
    if (ia == ib) return 0
    if (ia ~ /worker-/) {
        if (ib ~ /worker-/) return (ia<ib)?-1:1
        return -1
    }
    if (ib ~ /worker-/) return 1
    return (ia<ib)?-1:1
}

# sort by value in logs folder name
function testcase_compare(ia,va,ib,vb  ,ta,tb) {
    if (ia == ib) return 0
    if ((ia ~ /^[0-9]{4}-[0-9]{6}-/) && (ib ~ /^[0-9]{4}-[0-9]{6}-/)) {
      ta=mktime(gensub(/^([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2}).*/,"1970 \\1 \\2 \\3 \\4 \\5",1,ia))
      tb=mktime(gensub(/^([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2}).*/,"1970 \\1 \\2 \\3 \\4 \\5",1,ib))
      if (ta<tb) return -1
      if (ta>tb) return 1
      if ((ia ~ /^[0-9]{4}-[0-9]{6}-[lb][0-9][0-9]*/) && (ib ~ /^[0-9]{4}-[0-9]{6}-[lb][0-9][0-9]*/)) {
        ta=gensub(/[0-9]{4}-[0-9]{6}-[lb]([0-9]*).*/,"\\1",1,ia)*1
        tb=gensub(/[0-9]{4}-[0-9]{6}-[lb]([0-9]*).*/,"\\1",1,ib)*1
        if (ta<tb) return -1
        if (ta>tb) return 1
        if ((ia ~ /^[0-9]{4}-[0-9]{6}-l[0-9][0-9]*b[0-9][0-9]*/) && (ib ~ /^[0-9]{4}-[0-9]{6}-l[0-9][0-9]*b[0-9][0-9]*/)) {
          ta=gensub(/[0-9]{4}-[0-9]{6}-l[0-9]*b([0-9]*).*/,"\\1",1,ia)*1
          tb=gensub(/[0-9]{4}-[0-9]{6}-l[0-9]*b([0-9]*).*/,"\\1",1,ib)*1
          if (ta<tb) return -1
          if (ta>tb) return 1
        }
      }
    }
    return (ia<ib)?-1:1
}

function summarize_data(data,data_summary,    tc,h,itr) {
    for (tc in data) {
        for (hr in data[tc]) {
            for (itr in data[tc][hr]) {
                data_summary[tc][hr"/avg"][itr]=calc_avg(data[tc][hr][itr])
                data_summary[tc][hr"/med"][itr]=calc_median(data[tc][hr][itr])
                data_summary[tc][hr"/max"][itr]=calc_max(data[tc][hr][itr])
            }
        }
    }
}

function write_2d_data(title, tcsp, data, data_type, portal, ith, sortfunc, hiddenrow    ,kl_uniq,ksp,dn,dii,itc,k,i,nk) {
    if (length(data)==0) return
    split("", kl_uniq)
    ntc=length(tcsp)
    for (itc=1;itc<=ntc;itc++)
        if (length(data[tcsp[itc]])>0)
            for (k in data[tcsp[itc]])
                kl_uniq[k]=1
    nk=asorti(kl_uniq,ksp,sortfunc)
    if (nk>0) {
        empty_lines(2)
        print "<Row>"
        print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">"escape(title)"</Data></Cell>"
        print "</Row>"

        if (data_type == "Number") {
            # calculate median
            split("", dn)
            split("", dii)
            dn[0][0]=0
            dii[0][0]=0
            for (itc=1;itc<=ntc;itc++) {
                if (length(data[tcsp[itc]])>0) {
                    for (k in data[tcsp[itc]]) {
                        if (length(data[tcsp[itc]][k])>0) {
                            m=calc_median(data[tcsp[itc]][k])
                            for (i in data[tcsp[itc]][k]) {
                                dn[itc][k]=i*1
                                dii[itc][k]=i
                                break
                            }
                            for (i in data[tcsp[itc]][k]) {
                                if (i*1 > dn[itc][k]*1) dn[itc][k]=i*1
                                if (int(m*100)==int(data[tcsp[itc]][k][i]*100))
                                    dii[itc][k]=i
                            }
                        }
                    }
                }
            }
        }

        for(k=1;k<=nk;k++) {
            if (hiddenrow!="" && ksp[k] !~ hiddenrow) {
                print "<Row ss:Hidden=\"1\">"
            } else {
                print "<Row>"
            }
            print "<Cell ss:StyleID=\"border\"><Data ss:Type=\"String\">" escape(remove_prefix(ksp[k])) "</Data></Cell>"
            for (itc=1;itc<=ntc;itc++) {
                if (data_type=="String") {
                    if (length(data[tcsp[itc]][ksp[k]])>0) {
                        href=length(portal)>0 && length(portal[tcsp[itc]])>0?" ss:HRef=\""portal[tcsp[itc]]"\"":""
                        print "<Cell ss:Index=\"" ith[itc] "\" ss:StyleID=\"border\""href"><Data ss:Type=\"String\">" escape(data[tcsp[itc]][ksp[k]][1]) "</Data></Cell>"
                    } else {
                        print "<Cell ss:Index=\"" ith[itc] "\" ss:StyleID=\"border\"><Data ss:Type=\"String\"></Data></Cell>"
                    }
                }
                if (data_type=="Number") {
                    if (length(data[tcsp[itc]])>0 && length(data[tcsp[itc]][ksp[k]])>0 && length(data[tcsp[itc]][ksp[k]][dii[itc][ksp[k]]])>0) {
                        print "<Cell ss:Index=\"" ith[itc] "\" ss:StyleID=\"border\"><Data ss:Type=\"Number\">" data[tcsp[itc]][ksp[k]][dii[itc][ksp[k]]]*1 "</Data></Cell>"
                    } else {
                        print "<Cell ss:Index=\"" ith[itc] "\" ss:StyleID=\"border\"><Data ss:Type=\"Number\"></Data></Cell>"
                    }
                    if (dn[itc][ksp[k]]>1) {
                        for(i=1;i<=dn[itc][ksp[k]];i++) {
                            style=(i==dii[itc][ksp[k]])?"-median":""
                            if (length(data[tcsp[itc]][ksp[k]][i])>0) {
                                print "<Cell ss:StyleID=\"border" style "\"><Data ss:Type=\"Number\">" data[tcsp[itc]][ksp[k]][i]*1 "</Data></Cell>"
                            } else {
                                print "<Cell ss:StyleID=\"border" style "\"><Data ss:Type=\"Number\"></Data></Cell>"
                            }
                        }
                    }
                }
            }
            print "</Row>"
        }
    }
}

END {
    summarize_data(pcm_power, pcm_power_summary)
    summarize_data(pdu_power, pdu_power_summary)
    summarize_data(emon_power, emon_power_summary)
    summarize_data(uprof_power, uprof_power_summary)
    summarize_data(perfspect_power, perfspect_power_summary)
    summarize_data(emon_cpu_util, emon_cpu_util_summary)
    summarize_data(perfspect_cpu_util, perfspect_cpu_util_summary)
    summarize_data(sar_cpu_util, sar_cpu_util_summary)
    summarize_data(collectd_cpu_util, collectd_cpu_util_summary)
    summarize_data(igt_package_power, igt_package_power_summary)
    summarize_data(igt_render3d_busy, igt_render3d_busy_summary)
    summarize_data(igt_blitter_busy, igt_blitter_busy_summary)
    summarize_data(igt_video_busy, igt_video_busy_summary)
    summarize_data(igt_video_enhance_busy, igt_video_enhance_busy_summary)
    summarize_data(igt_compute_busy, igt_compute_busy_summary)
    summarize_data(igt_unknown_busy, igt_unknown_busy_summary)
    summarize_data(turbostat_pkgwatt, turbostat_pkgwatt_summary)
    summarize_data(turbostat_gfxwatt, turbostat_gfxwatt_summary)
    summarize_data(turbostat_corwatt, turbostat_corwatt_summary)
    summarize_data(turbostat_ramwatt, turbostat_ramwatt_summary)
    summarize_data(turbostat_busy, turbostat_busy_summary)

    add_xls_header(1)

    nwl=asorti(kpis_v, wlsp, "@ind_str_asc")
    for (iwl=1;iwl<=nwl;iwl++) {
        print "<Worksheet ss:Name=\"" ws_name2(wlsp[iwl]) "\">"
        print "<Table>"

        th=2
        ntc=asorti(kpis_v[wlsp[iwl]], tcsp, "testcase_compare")
        split("", hssp)
        for (itc=1;itc<=ntc;itc++) {
            ith[itc]=th++

            nk1=length(sutinfo_values[tcsp[itc]])
            if (nk1>0) {
                asorti(sutinfo_values[tcsp[itc]], tmp, "host_compare")
                for (ih=1;ih<=nk1;ih++)
                    hssp[itc][ih]=tmp[ih]
                nk1--
            }

            for (k in kpis_v[wlsp[iwl]][tcsp[itc]])
                for (itr in kpis_v[wlsp[iwl]][tcsp[itc]][k])
                    if (itr>nk1) nk1=itr

            for (k=1;k<=nk1;k++)
                print "<Column ss:Index=\"" (th++) "\" ss:Hidden=\"1\" ss:AutoFitWidth=\"0\"/>"
        }
        ith[ntc+1]=th

        if (has_data(csp, wlsp[iwl], tcsp)==1) {
            print "<Row>"
            add_sutinfo_cell("CSP")
            for (itc=1;itc<=ntc;itc++) {
                if (length(csp[wlsp[iwl]][tcsp[itc]])>0) {
                    add_sutinfo_cell_ex(ith[itc], csp[wlsp[iwl]][tcsp[itc]])
                } else {
                    add_sutinfo_cell_ex(ith[itc], "")
                }
            }
            print "</Row>"
            print "<Row>"
            add_sutinfo_cell("Instance Type")
            for (itc=1;itc<=ntc;itc++) {
                if (length(instance_type[wlsp[iwl]][tcsp[itc]])>0) {
                    add_sutinfo_cell_ex(ith[itc], instance_type[wlsp[iwl]][tcsp[itc]])
                } else {
                    add_sutinfo_cell_ex(ith[itc], "")
                }
            }
            print "</Row>"
        }

        add_sutinfo_brief(tcsp, ith, hssp)

        write_2d_data("Workload Ingredients:", tcsp, bom[wlsp[iwl]], "String", portal_null, ith, "@ind_str_asc", "")
        write_2d_data("Workload Parameters:", tcsp, tunables[wlsp[iwl]], "String", portal_null, ith, "@ind_str_asc", "")
        write_2d_data("Workload Logs:", tcsp, logs[wlsp[iwl]], "String", portal[wlsp[iwl]], ith, "@ind_str_asc", "")
        write_2d_data("Workload KPI:", tcsp, kpis_v[wlsp[iwl]], "Number", portal_null, ith, "@ind_str_asc", "")
        write_2d_data("pcm socket power (W):", tcsp, pcm_power_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("uprof socket power (W):", tcsp, uprof_power_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("pdu power (W):", tcsp, pdu_power_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("emon packet power (W):", tcsp, emon_power_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("perfspect packet power (W):", tcsp, perfspect_power_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("emon cpu util (%):", tcsp, emon_cpu_util_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("perfspect cpu util (%):", tcsp, perfspect_cpu_util_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("sar cpu util (%):", tcsp, sar_cpu_util_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("collectd cpu util (%):", tcsp, collectd_cpu_util_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt package power (W):", tcsp, igt_package_power_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt render3d busy (%):", tcsp, igt_render3d_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt blitter busy (%):", tcsp, igt_blitter_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt video busy (%):", tcsp, igt_video_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt video enhance busy (%):", tcsp, igt_video_enhance_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt compute busy (%):", tcsp, igt_compute_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("igt unknown busy (%):", tcsp, igt_unknown_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("turbostat pkg power (W):", tcsp, turbostat_pkgwatt_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("turbostat gfx power (W):", tcsp, turbostat_gfxwatt_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("turbostat core power (W):", tcsp, turbostat_corwatt_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("turbostat ram power (W):", tcsp, turbostat_ramwatt_summary, "Number", portal_null, ith, "host_compare", "worker-0/")
        write_2d_data("turbostat busy (%):", tcsp, turbostat_busy_summary, "Number", portal_null, ith, "host_compare", "worker-0/")

        print "</Table>"
        print "</Worksheet>"
    }
    if (nwl<1)
        print "<Worksheet ss:Name=\"Sheet1\"></Worksheet>"
    print "</Workbook>"
}

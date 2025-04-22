#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    split("", prefixes)
    split("abcdefghijklmnopqrstuvwxyz",ps,"")
    i=0
    for (x in ps)
       for (y in ps)
           prefixes[++i]=ps[x]ps[y]
}

function add_prefix(k,k_uniq,tc  ,kk) {
    kk=""
    k_uniq[tc][""]=""
    if (length(k_uniq[tc][k])>0) kk=k_uniq[tc][k]
    if (kk=="") {
      kk=prefixes[length(k_uniq[tc])]","k
      k_uniq[tc][k]=kk
    }
    return kk
}

function remove_prefix(k) {
    return gensub(/^[a-z][a-z][,]/,"",1,k)
}

function calc_median(values   ,m,n,v_sorted) {
    m=0
    if (length(values)>0) {
        n=asort(values, v_sorted, "@val_num_asc")
        m=(n%2 == 0)?v_sorted[n/2]:v_sorted[(n+1)/2]
    }
    return int(m*100)/100
}

function calc_avg(values      ,s,v) {
    s=0
    if (length(values)>0) {
        for (v in values)
            s=s+values[v]
        s=s/length(values)
    }
    return int(s*100)/100
}

function calc_max(values      ,m,v) {
    m=0
    if (length(values)>0)
        for (v in values)
            if (values[v]>m || m==0)
                m=values[v]
    return int(m*100)/100
}

function escape(text) {
    text=gensub(/</,"\\&lt;","g",text)
    text=gensub(/>/,"\\&gt;","g",text)
    text=gensub(/.u0026/,"\\&amp;","g",text)
    return text
}

function add_xls_header(align_left) {
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    print "<?mso-application progid=\"Excel.Sheet\"?>"
    print "<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\""
    print "xmlns:o=\"urn:schemas-microsoft-com:office:office\""
    print "xmlns:x=\"urn:schemas-microsoft-com:office:excel\""
    print "xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\""
    print "xmlns:html=\"http://www.w3.org/TR/REC-html40\">"

    print "<Styles>"
    print "<Style ss:ID=\"Default\" ss:Name=\"Normal\">"
    print "<Font ss:FontName=\"Verdana\" x:Family=\"Swiss\" ss:Size=\"10\"/>"
    print "</Style>"
    print "<Style ss:ID=\"border\">"
    print "<Borders>"
    print "<Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "</Borders>"
    if (align_left) print "<Alignment ss:Horizontal=\"Left\" ss:Vertical=\"Bottom\"/>"
    print "</Style>"
    print "<Style ss:ID=\"border-primary\">"
    print "<Borders>"
    print "<Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "</Borders>"
    print "<Interior ss:Color=\"#D9D9D9\" ss:Pattern=\"Solid\"/>"
    if (align_left) print "<Alignment ss:Horizontal=\"Left\" ss:Vertical=\"Bottom\"/>"
    print "</Style>"
    print "<Style ss:ID=\"border-median\">"
    print "<Borders>"
    print "<Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "<Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "<Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "<Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "</Borders>"
    if (align_left) print "<Alignment ss:Horizontal=\"Left\" ss:Vertical=\"Bottom\"/>"
    print "</Style>"
    print "<Style ss:ID=\"border-median-primary\">"
    print "<Borders>"
    print "<Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "<Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "<Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "<Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#FF0000\"/>"
    print "</Borders>"
    if (align_left) print "<Alignment ss:Horizontal=\"Left\" ss:Vertical=\"Bottom\"/>"
    print "<Interior ss:Color=\"#D9D9D9\" ss:Pattern=\"Solid\"/>"
    print "</Style>"
    print "<Style ss:ID=\"sutinfo\">"
    print "<Borders>"
    print "<Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "<Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\" ss:Color=\"#000000\"/>"
    print "</Borders>"
    print "<Alignment ss:Horizontal=\"Left\" ss:Vertical=\"Bottom\"/>"
    print "</Style>"
    print "</Styles>"
}

function ws_name_ex(a) {
    a1=gensub(filter,"","g",a)
    if (length(a1)>26) a1=substr(a1,length(a1)-26)
    return gensub(/^[^-_]+[-_](.*)$/,"\\1",1,a1)
}

function ws_name(a) {
    a1=ws_name_ex(a)
    if (ws_uniq[a1] == "") {
        ws_uniq[a1]=a
        return a1
    }
    print "Worksheet name conflict: "a1 > "/dev/stderr"
    print "previous: "ws_uniq[a1] > "/dev/stderr"
    print "new: "a > "/dev/stderr"
    exit 3
}

function ws_name_ex2(a) {
    a1=gensub(filter,"","g",a)
    if (length(a1)>26) a1=substr(a1,length(a1)-26)
    return a1
}

function ws_name2(a) {
    a1=ws_name_ex2(a)
    if (ws_uniq[a1] == "") {
        ws_uniq[a1]=a
        return a1
    }
    print "Worksheet name conflict: "a1 > "/dev/stderr"
    print "previous: "ws_uniq[a1] > "/dev/stderr"
    print "new: "a > "/dev/stderr"
    exit 3
}


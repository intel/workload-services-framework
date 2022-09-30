#!/usr/bin/gawk

function median(v) {
    n=asort(v, v_sorted, "@val_num_asc")
    if (n%2 == 0) {
        return v_sorted[n/2]
    } else {
        return v_sorted[(n+1)/2]
    }
}

function escape(text) {
    text=gensub(/</,"\\&lt;","g",text)
    text=gensub(/>/,"\\&gt;","g",text)
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
    print "<Style ss:ID=\"svrinfo\">"
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


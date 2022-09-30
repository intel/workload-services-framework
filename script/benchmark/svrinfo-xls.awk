#!/usr/bin/gawk

function add_svrinfo_cell(vv) {
    t=(vv==vv*1)?"Number":"String"
    print "<Cell ss:StyleID=\"svrinfo\"><Data ss:Type=\"" t "\">" escape(vv) "</Data></Cell>"
}

function add_svrinfo_row(ws, g, k) {
    print "<Row>"
    add_svrinfo_cell(g"."k)
    for (p in svrinfo_values[ws])
        for (s in svrinfo_values[ws][p])
            add_svrinfo_cell(svrinfo_values[ws][p][s][g][k][1])
    print "</Row>"
}

function add_svrinfo_isa_summary(ws, g) {
    print "<Row>"
    add_svrinfo_cell(g)
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            vv=""
            for (k in svrinfo_values[ws][p][s][g])
                if (svrinfo_values[ws][p][s][g][k][1] == "Yes")
                    vv=vv", "gensub(/-.*/,"",1,k)
            add_svrinfo_cell(gensub(/^, /,"",1,vv))
        }
    }
    print "</Row>"
}

function add_svrinfo_accelerator_summary(ws, g) {
    print "<Row>"
    add_svrinfo_cell(g)
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            vv=""
            for (k in svrinfo_values[ws][p][s][g])
                if (svrinfo_values[ws][p][s][g][k][1]>0)
                    vv=vv", "k":"svrinfo_values[ws][p][s][g][k][1]
            add_svrinfo_cell(gensub(/^, /,"",1,vv))
        }
    }
    print "</Row>"
}

function add_svrinfo_nic_summary(ws, g, n, m) {
    n1=0
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            n2=length(svrinfo_values[ws][p][s][g][m])
            if (n2>n1) n1=n2
        }
    }
    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        add_svrinfo_cell((n2==1)?g:"")
        for (p in svrinfo_values[ws]) {
            for (s in svrinfo_values[ws][p]) {
                vv=""
                n3=0
                for (i in svrinfo_values[ws][p][s][g][m]) {
                    n3++
                    if (n3==n2) {
                        vv=svrinfo_values[ws][p][s][g][n][i]": "svrinfo_values[ws][p][s][g][m][i]
                        break
                    }
                }
                add_svrinfo_cell(vv)
            }
        }
        print "</Row>"
    }
}

function add_svrinfo_disk_summary(ws, g, n, m) {
    n1=0
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            n2=0
            for (i in svrinfo_values[ws][p][s][g][m])
                if (length(svrinfo_values[ws][p][s][g][m][i])>0) n2++
            if (n2>n1) n1=n2
        }
    }

    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        add_svrinfo_cell((n2==1)?g:"")
        for (p in svrinfo_values[ws]) {
            for (s in svrinfo_values[ws][p]) {
                n3=0
                vv=""
                for (i in svrinfo_values[ws][p][s][g][m]) {
                    if (length(svrinfo_values[ws][p][s][g][m][i])>0) n3++
                    if (n3==n2) {
                        vv=svrinfo_values[ws][p][s][g][n][i]": "svrinfo_values[ws][p][s][g][m][i]
                        break
                    }
                }
                add_svrinfo_cell(vv)
            }
        }
        print "</Row>"
    }
}

function add_svrinfo_security_summary(ws, g) {
    n1=0
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            n2=length(svrinfo_values[ws][p][s][g])
            if (n2>n1) n1=n2
        }
    }
    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        g1=(n2==1)?g:""
        add_svrinfo_cell(g1)
        for (p in svrinfo_values[ws]) {
            for (s in svrinfo_values[ws][p]) {
                vv=""
                n3=0
                for (k in svrinfo_values[ws][p][s][g]) {
                    n3++
                    if (n3==n2) {
                        vv=k": "gensub(/\s*[(].*[)].*/,"",1,svrinfo_values[ws][p][s][g][k][1])
                        break;
                    }
                }
                add_svrinfo_cell(vv)
            }
        }
        print "</Row>"
    }
}

function find_svrinfo_phost(ws, p) {
    if (length(svrinfo_values[ws][p])==1)
        for (s in svrinfo_values[ws][p])
            return s
    for (s in svrinfo_values[ws][p])
        for (i in svrinfo_values[ws][p][s]["Host"]["Name"])
            if (svrinfo_values[ws][p][s]["Host"]["Name"][i] == phost)
                return s
    return ""
}

function add_svrinfo_cell_ex(i, vv) {
    style=(vv==vv*1)?"Number":"String"
    print "<Cell ss:Index=\"" i "\" ss:StyleID=\"svrinfo\"><Data ss:Type=\"" style "\">" escape(vv) "</Data></Cell>"
}

function add_svrinfo_row_ex(ws, psp, ith, g, k) {
    print "<Row>"
    add_svrinfo_cell(g"."k)
    np=length(psp)
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        add_svrinfo_cell_ex(ith[p1], svrinfo_values[ws][psp[p1]][s][g][k][1])
    }
    print "</Row>"
}

function add_svrinfo_nic_summary_ex(ws, psp, ith, g, n, m) {
    np=length(psp)
    n1=0
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        n2=length(svrinfo_values[ws][psp[p1]][s][g][m])
        if (n2>n1) n1=n2
    }
    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        add_svrinfo_cell((n2==1)?g:"")
        for (p1=1;p1<=np;p1++) {
            s=find_svrinfo_phost(ws, psp[p1])
            vv=""
            n3=0
            for (i in svrinfo_values[ws][psp[p1]][s][g][m]) {
                n3++
                if (n3==n2) {
                    vv=svrinfo_values[ws][psp[p1]][s][g][n][i]": "svrinfo_values[ws][psp[p1]][s][g][m][i]
                    break
                }
            }
            add_svrinfo_cell_ex(ith[p1], vv)
        }
        print "</Row>"
    }
}

function add_svrinfo_security_summary_ex(ws, psp, ith, g) {
    np=length(psp)
    n1=0
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        n2=length(svrinfo_values[ws][psp[p1]][s][g])
        if (n2>n1) n1=n2
    }
    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        add_svrinfo_cell((n2==1)?g:"")
        for (p1=1;p1<=np;p1++) {
            s=find_svrinfo_phost(ws, psp[p1])
            vv=""
            n3=0
            for (k in svrinfo_values[ws][psp[p1]][s][g]) {
                n3++
                if (n3==n2) {
                    vv=k": "gensub(/\s*[(].*[)].*/,"",1,svrinfo_values[ws][psp[p1]][s][g][k][1])
                    break
                }
            }
            add_svrinfo_cell_ex(ith[p1], vv)
        }
        print "</Row>"
    }
}

function add_svrinfo_disk_summary_ex(ws, psp, ith, g, n, m) {
    np=length(psp)
    n1=0
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        n2=0
        for (i in svrinfo_values[ws][psp[p1]][s][g][m])
            if (length(svrinfo_values[ws][psp[p1]][s][g][m][i])>0) n2++
        if (n2>n1) n1=n2
    }

    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        g1=(n2==1)?g:""
        add_svrinfo_cell(g)
        for (p1=1;p1<=np;p1++) {
            s=find_svrinfo_phost(ws, psp[p1])
            n3=0
            vv=""
            for (i in svrinfo_values[ws][psp[p1]][s][g][m]) {
                if (length(svrinfo_values[ws][psp[p1]][s][g][m][i])>0) n3++
                if (n3==n2) {
                    vv=svrinfo_values[ws][psp[p1]][s][g][n][i]":"svrinfo_values[ws][psp[p1]][s][g][m][i]
                    break
                }
            }
            add_svrinfo_cell(vv)
        }
        print "</Row>"
    }
}

function add_svrinfo(ws) {
    print "<Worksheet ss:Name=\"" ws_name(ws"-INF") "\">"
    print "<Table>"

    add_svrinfo_row(ws, "Host", "Name")
    add_svrinfo_row(ws, "Host", "Time")
    add_svrinfo_row(ws, "System", "Manufacturer")
    add_svrinfo_row(ws, "System", "Product Name")
    add_svrinfo_row(ws, "System", "Version")
    add_svrinfo_row(ws, "System", "Serial #")
    add_svrinfo_row(ws, "System", "UUID")

    add_svrinfo_row(ws, "Baseboard", "Manifacturer")
    add_svrinfo_row(ws, "Baseboard", "Product Name")
    add_svrinfo_row(ws, "Baseboard", "Version")
    add_svrinfo_row(ws, "Baseboard", "Serial #")
    
    add_svrinfo_row(ws, "Chassis", "Manufacturer")
    add_svrinfo_row(ws, "Chassis", "Type")
    add_svrinfo_row(ws, "Chassis", "Version")
    add_svrinfo_row(ws, "Chassis", "Serial #")

    add_svrinfo_row(ws, "BIOS", "Vendor")
    add_svrinfo_row(ws, "BIOS", "Version")
    add_svrinfo_row(ws, "BIOS", "Release Date")

    add_svrinfo_row(ws, "Operating System", "OS")
    add_svrinfo_row(ws, "Operating System", "Kernel")
    add_svrinfo_row(ws, "Operating System", "Microcode")

    add_svrinfo_row(ws, "Software Version", "GCC")
    add_svrinfo_row(ws, "Software Version", "GLIBC")
    add_svrinfo_row(ws, "Software Version", "Binutils")
    add_svrinfo_row(ws, "Software Version", "Python")
    add_svrinfo_row(ws, "Software Version", "Python3")
    add_svrinfo_row(ws, "Software Version", "Java")
    add_svrinfo_row(ws, "Software Version", "OpenSSL")

    add_svrinfo_row(ws, "CPU", "CPU Model")
    add_svrinfo_row(ws, "CPU", "Architecture")
    add_svrinfo_row(ws, "CPU", "Microarchitecture")
    add_svrinfo_row(ws, "CPU", "Family")
    add_svrinfo_row(ws, "CPU", "Model")
    add_svrinfo_row(ws, "CPU", "Stepping")
    add_svrinfo_row(ws, "CPU", "Base Frequency")
    add_svrinfo_row(ws, "CPU", "Maximum Frequency")
    add_svrinfo_row(ws, "CPU", "All-core Maximum Frequency")
    add_svrinfo_row(ws, "CPU", "CPUs")
    add_svrinfo_row(ws, "CPU", "On-line CPU List")
    add_svrinfo_row(ws, "CPU", "Hyperthreading")
    add_svrinfo_row(ws, "CPU", "Cores per Socket")
    add_svrinfo_row(ws, "CPU", "Sockets")
    add_svrinfo_row(ws, "CPU", "NUMA Nodes")
    add_svrinfo_row(ws, "CPU", "NUMA CPU List")
    add_svrinfo_row(ws, "CPU", "CHA Count")
    add_svrinfo_row(ws, "CPU", "L1d Cache")
    add_svrinfo_row(ws, "CPU", "L1i Cache")
    add_svrinfo_row(ws, "CPU", "L2 Cache")
    add_svrinfo_row(ws, "CPU", "L3 Cache")
    add_svrinfo_row(ws, "CPU", "Memory Channels")
    add_svrinfo_row(ws, "CPU", "Prefetchers")
    add_svrinfo_row(ws, "CPU", "Intel Turbo Boost")
    add_svrinfo_row(ws, "CPU", "PPINs")

    add_svrinfo_isa_summary(ws, "ISA")
    add_svrinfo_accelerator_summary(ws, "Accelerator")

    add_svrinfo_row(ws, "Power", "TDP")
    add_svrinfo_row(ws, "Power", "Power & Perf Policy")
    add_svrinfo_row(ws, "Power", "Frequency Governer")
    add_svrinfo_row(ws, "Power", "Frequency Driver")
    add_svrinfo_row(ws, "Power", "MAX C-State")

    add_svrinfo_row(ws, "Memory", "Installed Memory")
    add_svrinfo_row(ws, "Memory", "MemTotal")
    add_svrinfo_row(ws, "Memory", "MemFree")
    add_svrinfo_row(ws, "Memory", "MemAvailable")
    add_svrinfo_row(ws, "Memory", "Buffers")
    add_svrinfo_row(ws, "Memory", "Cached")
    add_svrinfo_row(ws, "Memory", "HugePages_Total")
    add_svrinfo_row(ws, "Memory", "Hugepagesize")
    add_svrinfo_row(ws, "Memory", "Transparent Huge Pages")
    add_svrinfo_row(ws, "Memory", "Automatic NUMA Balancing")
    add_svrinfo_row(ws, "Memory", "Populated Memory Channels")

    add_svrinfo_row(ws, "GPU", "Manufacturer")
    add_svrinfo_row(ws, "GPU", "Model")

    add_svrinfo_nic_summary(ws, "NIC", "Name", "Model")
    add_svrinfo_nic_summary(ws, "Network IRQ Mapping", "Interface", "CPU:IRQs CPU:IRQs ...")
    add_svrinfo_disk_summary(ws, "Disk", "NAME", "MODEL")
    add_svrinfo_security_summary(ws, "Vulnerability")

    add_svrinfo_row(ws, "PMU", "cpu_cycles")
    add_svrinfo_row(ws, "PMU", "instructions")
    add_svrinfo_row(ws, "PMU", "ref_cycles")
    add_svrinfo_row(ws, "PMU", "topdown_slots")
    print "</Table>"
    print "</Worksheet>"
}

function add_svrinfo_ex(ws, psp, ith) {
    add_svrinfo_row_ex(ws, psp, ith, "Host", "Name")
    add_svrinfo_row_ex(ws, psp, ith, "Host", "Time")
    add_svrinfo_row_ex(ws, psp, ith, "System", "Manufacturer")
    add_svrinfo_row_ex(ws, psp, ith, "System", "Product Name")
    add_svrinfo_row_ex(ws, psp, ith, "BIOS", "Version")
    add_svrinfo_row_ex(ws, psp, ith, "Operating System", "OS")
    add_svrinfo_row_ex(ws, psp, ith, "Operating System", "Kernel")
    add_svrinfo_row_ex(ws, psp, ith, "Operating System", "Microcode")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "CPU Model")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "Base Frequency")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "Maximum Frequency")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "All-core Maximum Frequency")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "CPUs")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "Cores per Socket")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "Sockets")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "NUMA Nodes")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "Prefetchers")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "Intel Turbo Boost")
    add_svrinfo_row_ex(ws, psp, ith, "CPU", "PPINs")
    add_svrinfo_row_ex(ws, psp, ith, "Power", "Power & Perf Policy")
    add_svrinfo_row_ex(ws, psp, ith, "Power", "TDP")
    add_svrinfo_row_ex(ws, psp, ith, "Power", "Frequency Driver")
    add_svrinfo_row_ex(ws, psp, ith, "Power", "Frequency Governer")
    add_svrinfo_row_ex(ws, psp, ith, "Power", "MAX C-State")
    add_svrinfo_row_ex(ws, psp, ith, "Memory", "Installed Memory")
    add_svrinfo_row_ex(ws, psp, ith, "Memory", "Hugepagesize")
    add_svrinfo_row_ex(ws, psp, ith, "Memory", "Transparent Huge Pages")
    add_svrinfo_row_ex(ws, psp, ith, "Memory", "Automatic NUMA Balancing")
    add_svrinfo_nic_summary_ex(ws, psp, ith, "NIC", "Name", "Model")
    add_svrinfo_nic_summary_ex(ws, psp, ith, "Network IRQ Mapping", "Interface", "CPU:IRQs CPU:IRQs ...")
    add_svrinfo_disk_summary_ex(ws, psp, ith, "Disk", "NAME", "MODEL")
    add_svrinfo_security_summary_ex(ws, psp, ith, "Vulnerability")
}

#!/usr/bin/gawk

function add_svrinfo_cell(vv) {
    t=(vv==vv*1)?"Number":"String"
    print "<Cell ss:StyleID=\"svrinfo\"><Data ss:Type=\"" t "\">" escape(vv) "</Data></Cell>"
}

function add_svrinfo_row(ws, c, g, k) {
    print "<Row>"
    add_svrinfo_cell(g"."k)
    for (p in svrinfo_values[ws])
        for (s in svrinfo_values[ws][p])
            add_svrinfo_cell(svrinfo_values[ws][p][s][c][g][1][k])
    print "</Row>"
}

function add_svrinfo_isa_summary(ws, c, g) {
    print "<Row>"
    add_svrinfo_cell(g)
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            vv=""
            for (i in svrinfo_values[ws][p][s][c][g])
                for (k in svrinfo_values[ws][p][s][c][g][i])
                    if (svrinfo_values[ws][p][s][c][g][i][k] == "Yes")
                        vv=vv", "gensub(/-.*/,"",1,k)
            add_svrinfo_cell(gensub(/^, /,"",1,vv))
        }
    }
    print "</Row>"
}

function add_svrinfo_accelerator_summary(ws, c, g) {
    print "<Row>"
    add_svrinfo_cell(g)
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            vv=""
            for (i in svrinfo_values[ws][p][s][c][g])
                for (k in svrinfo_values[ws][p][s][c][g][i])
                    if (svrinfo_values[ws][p][s][c][g][i][k] == "1")
                        vv=vv", "k":"svrinfo_values[ws][p][s][c][g][i][k]
            add_svrinfo_cell(gensub(/^, /,"",1,vv))
        }
    }
    print "</Row>"
}

function add_svrinfo_nic_summary(ws, c, g, n, m) {
    n1=0
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            n2=length(svrinfo_values[ws][p][s][c][g])
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
                for (i in svrinfo_values[ws][p][s][c][g]) {
                    n3++
                    if (n3==n2) {
                        vv=svrinfo_values[ws][p][s][c][g][i][n]": "svrinfo_values[ws][p][s][c][g][i][m]
                        break
                    }
                }
                add_svrinfo_cell(vv)
            }
        }
        print "</Row>"
    }
}

function add_svrinfo_disk_summary(ws, c, g, n, m) {
    n1=0
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            n2=0
            for (i in svrinfo_values[ws][p][s][c][g])
                if (length(svrinfo_values[ws][p][s][c][g][i][m])>0) n2++
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
                for (i in svrinfo_values[ws][p][s][c][g]) {
                    if (length(svrinfo_values[ws][p][s][c][g][i][m])>0) n3++
                    if (n3==n2) {
                        vv=svrinfo_values[ws][p][s][c][g][i][n]": "svrinfo_values[ws][p][s][c][g][i][m]
                        break
                    }
                }
                add_svrinfo_cell(vv)
            }
        }
        print "</Row>"
    }
}

function add_svrinfo_security_summary(ws, c, g) {
    n1=0
    for (p in svrinfo_values[ws]) {
        for (s in svrinfo_values[ws][p]) {
            for (i in svrinfo_values[ws][p][s][c][g]) {
                n2=length(svrinfo_values[ws][p][s][c][g][i])
                if (n2>n1) n1=n2
            }
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
                for (i in svrinfo_values[ws][p][s][c][g]) {
                    for (k in svrinfo_values[ws][p][s][c][g][i]) {
                        n3++
                        if (n3==n2) {
                            vv=k": "gensub(/\s*[(].*[)].*/,"",1,svrinfo_values[ws][p][s][c][g][i][k])
                            break;
                        }
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
        if (s==svrinfo_phostip[ws][p])
            return s
    return s
}

function add_svrinfo_cell_ex(i, vv) {
    style=(vv==vv*1)?"Number":"String"
    print "<Cell ss:Index=\"" i "\" ss:StyleID=\"svrinfo\"><Data ss:Type=\"" style "\">" escape(vv) "</Data></Cell>"
}

function add_svrinfo_row_ex(ws, psp, ith, c, g, k) {
    print "<Row>"
    add_svrinfo_cell(g"."k)
    np=length(psp)
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        add_svrinfo_cell_ex(ith[p1], svrinfo_values[ws][psp[p1]][s][c][g][1][k])
    }
    print "</Row>"
}

function add_svrinfo_nic_summary_ex(ws, psp, ith, c, g, n, m) {
    np=length(psp)
    n1=0
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        n2=length(svrinfo_values[ws][psp[p1]][s][c][g])
        if (n2>n1) n1=n2
    }
    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        add_svrinfo_cell((n2==1)?g:"")
        for (p1=1;p1<=np;p1++) {
            s=find_svrinfo_phost(ws, psp[p1])
            vv=""
            n3=0
            for (i in svrinfo_values[ws][psp[p1]][s][c][g]) {
                n3++
                if (n3==n2) {
                    vv=svrinfo_values[ws][psp[p1]][s][c][g][i][n]": "svrinfo_values[ws][psp[p1]][s][c][g][i][m]
                    break
                }
            }
            add_svrinfo_cell_ex(ith[p1], vv)
        }
        print "</Row>"
    }
}

function add_svrinfo_security_summary_ex(ws, psp, ith, c, g) {
    np=length(psp)
    n1=0
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        for (i in svrinfo_values[ws][psp[p1]][s][c][g]) {
            n2=length(svrinfo_values[ws][psp[p1]][s][c][g][i])
            if (n2>n1) n1=n2
        }
    }
    for (n2=1;n2<=n1;n2++) {
        print "<Row>"
        add_svrinfo_cell((n2==1)?g:"")
        for (p1=1;p1<=np;p1++) {
            s=find_svrinfo_phost(ws, psp[p1])
            vv=""
            n3=0
            for (i in svrinfo_values[ws][psp[p1]][s][c][g]) {
                for (k in svrinfo_values[ws][psp[p1]][s][c][g][i]) {
                    n3++
                    if (n3==n2) {
                        vv=k": "gensub(/\s*[(].*[)].*/,"",1,svrinfo_values[ws][psp[p1]][s][c][g][i][k])
                        break
                    }
                }
            }
            add_svrinfo_cell_ex(ith[p1], vv)
        }
        print "</Row>"
    }
}

function add_svrinfo_disk_summary_ex(ws, psp, ith, c, g, n, m) {
    np=length(psp)
    n1=0
    for (p1=1;p1<=np;p1++) {
        s=find_svrinfo_phost(ws, psp[p1])
        n2=0
        for (i in svrinfo_values[ws][psp[p1]][s][c][g])
            if (length(svrinfo_values[ws][psp[p1]][s][c][g][i][m])>0) n2++
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
            for (i in svrinfo_values[ws][psp[p1]][s][c][g]) {
                if (length(svrinfo_values[ws][psp[p1]][s][c][g][i][m])>0) n3++
                if (n3==n2) {
                    vv=svrinfo_values[ws][psp[p1]][s][c][g][i][n]":"svrinfo_values[ws][psp[p1]][s][c][g][i][m]
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

    add_svrinfo_row(ws, "Configuration", "Host", "Name")
    add_svrinfo_row(ws, "Configuration", "Host", "Time")
    add_svrinfo_row(ws, "Configuration", "System", "Manufacturer")
    add_svrinfo_row(ws, "Configuration", "System", "Product Name")
    add_svrinfo_row(ws, "Configuration", "System", "Version")
    add_svrinfo_row(ws, "Configuration", "System", "Serial #")
    add_svrinfo_row(ws, "Configuration", "System", "UUID")

    add_svrinfo_row(ws, "Configuration", "Baseboard", "Manifacturer")
    add_svrinfo_row(ws, "Configuration", "Baseboard", "Product Name")
    add_svrinfo_row(ws, "Configuration", "Baseboard", "Version")
    add_svrinfo_row(ws, "Configuration", "Baseboard", "Serial #")
    
    add_svrinfo_row(ws, "Configuration", "Chassis", "Manufacturer")
    add_svrinfo_row(ws, "Configuration", "Chassis", "Type")
    add_svrinfo_row(ws, "Configuration", "Chassis", "Version")
    add_svrinfo_row(ws, "Configuration", "Chassis", "Serial #")

    add_svrinfo_row(ws, "Configuration", "BIOS", "Vendor")
    add_svrinfo_row(ws, "Configuration", "BIOS", "Version")
    add_svrinfo_row(ws, "Configuration", "BIOS", "Release Date")

    add_svrinfo_row(ws, "Configuration", "Operating System", "OS")
    add_svrinfo_row(ws, "Configuration", "Operating System", "Kernel")
    add_svrinfo_row(ws, "Configuration", "Operating System", "Microcode")

    add_svrinfo_row(ws, "Configuration", "Software Version", "GCC")
    add_svrinfo_row(ws, "Configuration", "Software Version", "GLIBC")
    add_svrinfo_row(ws, "Configuration", "Software Version", "Binutils")
    add_svrinfo_row(ws, "Configuration", "Software Version", "Python")
    add_svrinfo_row(ws, "Configuration", "Software Version", "Python3")
    add_svrinfo_row(ws, "Configuration", "Software Version", "Java")
    add_svrinfo_row(ws, "Configuration", "Software Version", "OpenSSL")

    add_svrinfo_row(ws, "Configuration", "CPU", "CPU Model")
    add_svrinfo_row(ws, "Configuration", "CPU", "Architecture")
    add_svrinfo_row(ws, "Configuration", "CPU", "Microarchitecture")
    add_svrinfo_row(ws, "Configuration", "CPU", "Family")
    add_svrinfo_row(ws, "Configuration", "CPU", "Model")
    add_svrinfo_row(ws, "Configuration", "CPU", "Stepping")
    add_svrinfo_row(ws, "Configuration", "CPU", "Base Frequency")
    add_svrinfo_row(ws, "Configuration", "CPU", "Maximum Frequency")
    add_svrinfo_row(ws, "Configuration", "CPU", "All-core Maximum Frequency")
    add_svrinfo_row(ws, "Configuration", "CPU", "CPUs")
    add_svrinfo_row(ws, "Configuration", "CPU", "On-line CPU List")
    add_svrinfo_row(ws, "Configuration", "CPU", "Hyperthreading")
    add_svrinfo_row(ws, "Configuration", "CPU", "Cores per Socket")
    add_svrinfo_row(ws, "Configuration", "CPU", "Sockets")
    add_svrinfo_row(ws, "Configuration", "CPU", "NUMA Nodes")
    add_svrinfo_row(ws, "Configuration", "CPU", "NUMA CPU List")
    add_svrinfo_row(ws, "Configuration", "CPU", "CHA Count")
    add_svrinfo_row(ws, "Configuration", "CPU", "L1d Cache")
    add_svrinfo_row(ws, "Configuration", "CPU", "L1i Cache")
    add_svrinfo_row(ws, "Configuration", "CPU", "L2 Cache")
    add_svrinfo_row(ws, "Configuration", "CPU", "L3 Cache")
    add_svrinfo_row(ws, "Configuration", "CPU", "Memory Channels")
    add_svrinfo_row(ws, "Configuration", "CPU", "Prefetchers")
    add_svrinfo_row(ws, "Configuration", "CPU", "Intel Turbo Boost")
    add_svrinfo_row(ws, "Configuration", "CPU", "PPINs")

    add_svrinfo_isa_summary(ws, "Configuration", "ISA")
    add_svrinfo_accelerator_summary(ws, "Configuration", "Accelerator")

    add_svrinfo_row(ws, "Configuration", "Power", "TDP")
    add_svrinfo_row(ws, "Configuration", "Power", "Power & Perf Policy")
    add_svrinfo_row(ws, "Configuration", "Power", "Frequency Governer")
    add_svrinfo_row(ws, "Configuration", "Power", "Frequency Driver")
    add_svrinfo_row(ws, "Configuration", "Power", "MAX C-State")

    add_svrinfo_row(ws, "Configuration", "Memory", "Installed Memory")
    add_svrinfo_row(ws, "Configuration", "Memory", "MemTotal")
    add_svrinfo_row(ws, "Configuration", "Memory", "MemFree")
    add_svrinfo_row(ws, "Configuration", "Memory", "MemAvailable")
    add_svrinfo_row(ws, "Configuration", "Memory", "Buffers")
    add_svrinfo_row(ws, "Configuration", "Memory", "Cached")
    add_svrinfo_row(ws, "Configuration", "Memory", "HugePages_Total")
    add_svrinfo_row(ws, "Configuration", "Memory", "Hugepagesize")
    add_svrinfo_row(ws, "Configuration", "Memory", "Transparent Huge Pages")
    add_svrinfo_row(ws, "Configuration", "Memory", "Automatic NUMA Balancing")
    add_svrinfo_row(ws, "Configuration", "Memory", "Populated Memory Channels")

    add_svrinfo_row(ws, "Configuration", "GPU", "Manufacturer")
    add_svrinfo_row(ws, "Configuration", "GPU", "Model")

    add_svrinfo_nic_summary(ws, "Configuration", "NIC", "Name", "Model")
    add_svrinfo_nic_summary(ws, "Configuration", "Network IRQ Mapping", "Interface", "CPU:IRQs CPU:IRQs ...")
    add_svrinfo_disk_summary(ws, "Configuration", "Disk", "NAME", "MODEL")
    add_svrinfo_security_summary(ws, "Configuration", "Vulnerability")

    add_svrinfo_row(ws, "Configuration", "PMU", "cpu_cycles")
    add_svrinfo_row(ws, "Configuration", "PMU", "instructions")
    add_svrinfo_row(ws, "Configuration", "PMU", "ref_cycles")
    add_svrinfo_row(ws, "Configuration", "PMU", "topdown_slots")
    print "</Table>"
    print "</Worksheet>"
}

function add_svrinfo_ex(ws, psp, ith) {
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Host", "Name")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Host", "Time")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "System", "Manufacturer")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "System", "Product Name")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "BIOS", "Version")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Operating System", "OS")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Operating System", "Kernel")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Operating System", "Microcode")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "CPU Model")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "Base Frequency")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "Maximum Frequency")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "All-core Maximum Frequency")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "CPUs")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "Cores per Socket")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "Sockets")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "NUMA Nodes")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "Prefetchers")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "Intel Turbo Boost")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "CPU", "PPINs")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Power", "Power & Perf Policy")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Power", "TDP")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Power", "Frequency Driver")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Power", "Frequency Governer")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Power", "MAX C-State")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Memory", "Installed Memory")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Memory", "Hugepagesize")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Memory", "Transparent Huge Pages")
    add_svrinfo_row_ex(ws, psp, ith, "Configuration", "Memory", "Automatic NUMA Balancing")
    add_svrinfo_nic_summary_ex(ws, psp, ith, "Configuration", "NIC", "Name", "Model")
    add_svrinfo_nic_summary_ex(ws, psp, ith, "Configuration", "Network IRQ Mapping", "Interface", "CPU:IRQs CPU:IRQs ...")
    add_svrinfo_disk_summary_ex(ws, psp, ith, "Configuration", "Disk", "NAME", "MODEL")
    add_svrinfo_security_summary_ex(ws, psp, ith, "Configuration", "Vulnerability")
}

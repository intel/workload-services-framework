#!/usr/bin/gawk

BEGIN {
    svrinfo_values_start=0
    svrinfo_names_start=0
    svrinfo_host_start=0
    svrinfo_ws="default"
    svrinfo_product="default"
}

/^#svrinfo: / {
    svrinfo_ws=gensub("^.*logs-(.*)[/]runs[/].*$","\\1",1,$2)
    svrinfo_product=$3
}

/^#svrinfo-\s*"Name":\s*".*",*\s*$/ && !svrinfo_values_start && !svrinfo_names_start {
    v=gensub(/^#svrinfo-\s*"Name":\s*"(.*)",*\s*$/, "\\1", 1, $0)
    if (svrinfo_host_start) {
        svrinfo_ip=v
    } else {
        svrinfo_group=v
    }
}

/^#svrinfo-\s*"AllHostValues":/ {
    svrinfo_host_start=1
}
    
svrinfo_names_start && !svrinfo_values_start && /^#svrinfo-\s*".*",*\s*$/ {
    svrinfo_names[++svrinfo_nnames]=gensub(/^#svrinfo-\s*"(.*)",*\s*$/, "\\1", 1, $0)
}

svrinfo_names_start && !svrinfo_values_start && /^#svrinfo-\s*]\s*$/ {
    svrinfo_names_start=0
}

/^#svrinfo-\s*"ValueNames":/ {
    svrinfo_names_start=1
    svrinfo_nnames=0
}

svrinfo_values_start && /^#svrinfo-\s*".*",*\s*$/ {
    n=svrinfo_names[(svrinfo_nvalues%svrinfo_nnames)+1]
    i=int(svrinfo_nvalues/svrinfo_nnames)+1
    ++svrinfo_nvalues
    svrinfo_values[svrinfo_ws][svrinfo_product][svrinfo_ip][svrinfo_group][n][i]=gensub(/^#svrinfo-\s*"(.*)",*\s*$/,"\\1",1,$0)
}

svrinfo_values_start && /^#svrinfo-\s*}\s*$/ {
    svrinfo_values_start=0
    svrinfo_host_start=0
}

/^#svrinfo-\s*"Values":/ {
    svrinfo_values_start=1
    svrinfo_nvalues=0
}


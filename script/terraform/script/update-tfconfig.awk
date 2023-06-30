#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    nspc=0
    nspm=0
    section=0
}

FNR==NR && /^\s*[a-z]+:\s*$/ {
    if (nspc==0) nspc=index($0,$1)
    if (index($0,$1)==nspc) section=$1
}

FNR==NR && /^\s*-\s*labels:/ && section=="cluster:" && index($0,$1)>=nspc {
    nsp=index($0,$1)
    if (nspm==0) {
        nspm=nsp
        vm_group="worker"
        ds="null"
        ns="null"
    } else if (nsp==nspm) {
        ++vm_count[vm_group]
        dsc[vm_group][vm_count[vm_group]]=ds
        nsc[vm_group][vm_count[vm_group]]=ns
        vm_group="worker"
        ds="null"
        ns="null"
    }
}

FNR==NR && /HAS-SETUP-DISK-MOUNT-/ && section=="cluster:" && index($0,$1)>nspm {
    ds="var.disk_spec_" gensub(/.*MOUNT-(.*):.*/,"\\1",1)
}

FNR==NR && /HAS-SETUP-DISK-SPEC-/ && section=="cluster:" && index($0,$1)>nspm {
    ds="var.disk_spec_" gensub(/.*SPEC-(.*):.*/,"\\1",1)
}

FNR==NR && /HAS-SETUP-NETWORK-SPEC-/ && section=="cluster:" && index($0,$1)>nspm {
    ns="var.network_spec_" gensub(/.*SPEC-(.*):.*/,"\\1",1)
}

FNR==NR && /vm_group:/ && section=="cluster:" && index($0,$1)>nspm {
    vm_group=$NF
}

FNR!=NR && FNR==1 {
    ++vm_count[vm_group]
    dsc[vm_group][vm_count[vm_group]]=ds
    nsc[vm_group][vm_count[vm_group]]=ns
    if (vm_count["controller"]<cvc) 
        vm_count["controller"]=cvc
    r=0
}

FNR!=NR && (/}\s*$/ || /}\s*#/) {
    r=0
}

FNR!=NR && /^\s*vm_count\s*=/ && r>0 {
    $0=gensub(/vm_count\s*=.*/,"vm_count = "count_value,1,$0)
}

FNR!=NR && /^\s*variable\s*["][a-z]+_profile["]\s*{/ {
    vm_group=gensub(/["]([a-z]+)_profile["]/,"\\1",1,$2)
    count_value=(vm_count[vm_group]>0)?vm_count[vm_group]:0
    r=1
}

FNR!=NR && /^\s*data_disk_spec\s*:/ && r>0 {
    $0=gensub(/data_disk_spec\s*:.*/,"data_disk_spec: "ds_value",",1,$0)
}

FNR!=NR && /^\s*network_spec\s*:/ && r>0 {
    $0=gensub(/network_spec\s*:.*/,"network_spec: "ns_value",",1,$0)
}

FNR!=NR && /^\s*merge[(]\s*var[.][a-z]+_profile\s*,\s*{/ {
    vm_group=gensub(/.*var[.]([a-z]+)_profile.*/,"\\1",1,$0)
    ds_value="null"
    for (g in dsc) {
        if (g==vm_group) {
            disk_spec=""
            for (i=1;i<=vm_count[g];i++)
                disk_spec=(disk_spec=="")?dsc[g][i]:disk_spec", "dsc[g][i]
            ds_value="["disk_spec"]"
        }
    }
    ns_value="null"
    for (g in nsc) {
        if (g==vm_group) {
            network_spec=""
            for (i=1;i<=vm_count[g];i++)
                network_spec=(network_spec=="")?nsc[g][i]:network_spec", "nsc[g][i]
            ns_value="["network_spec"]"
        }
    }
    r=1
}

FNR!=NR {
    print
}


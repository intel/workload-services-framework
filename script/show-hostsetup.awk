#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    nspc=0
    nspm=0
    section=0
    split("", hostsetup)
}

/^\s*[a-z]+:\s*$/ {
    if (nspc==0) nspc=index($0,$1)
    if (index($0,$1)==nspc) section=$1
}

/^\s*-\s*labels:/ && section=="cluster:" && index($0,$1)>=nspc {
    nsp=index($0,$1)
    if (nspm==0) {
        nspm=nsp
        vm_group="worker"
        split("", labels)
    } else if (nsp==nspm) {
        ++vm_count[vm_group]
        for (l in labels) {
            hostsetup[vm_group][l]=labels[l]
        }
        vm_group="worker"
        split("", labels)
    }
}

/HAS-SETUP-/ && section=="cluster:" && index($0,$1)>nspm {
    labels[$1]=$2
}

/vm_group:/ && section=="cluster:" && index($0,$1)>nspm {
    vm_group=$NF
}

END {
    ++vm_count[vm_group]
    for (l in labels) {
        hostsetup[vm_group][l]=labels[l]
    }
    print "Host Setup:"
    for (vm_group in vm_count) {
        print vm_count[vm_group]" "vm_group" host(s):"
        if (length(hostsetup[vm_group])>0) {
            for (l in hostsetup[vm_group]) {
                print "  "l,hostsetup[vm_group][l]
            }
        } else {
            print "  none"
        }
    }
    print ""
}

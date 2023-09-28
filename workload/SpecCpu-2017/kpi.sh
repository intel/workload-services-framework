#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -v numa=1 '
/no-numa/ {
    numa=0
}
END {
    print "## NUMA: "numa
}' */output.logs 2>/dev/null || true

awk '
/--copies/ {
    print "## COPIES: "$3
}
' */output.logs 2>/dev/null || true

awk '
/Not Run/ {
    next
}
/^spec.cpu2017.basemean:/ && $2!=0 {
    print "*"$1" "$2
    next
}
/^spec.cpu2017.basepeak:/ && $2!=0 {
    print $1" "$2
    next
}
/\.ratio:/ || /\.baseenergymean/ || /\.basemean/ || /\.basepeak/ {
    print $1" "$2
}
' */result/*.rsf 2>/dev/null || true


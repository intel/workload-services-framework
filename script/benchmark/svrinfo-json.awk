#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    svrinfo_ws="default"
    svrinfo_product="default"
}

/^#svrinfo: / {
    svrinfo_ws=gensub("^.*logs-([^/]*)[/].*$","\\1",1,$2)
    svrinfo_ip=gensub("^.*/(.*).json$","\\1",1,$2)
    svrinfo_product=$3
    svrinfo_phostip[svrinfo_ws][svrinfo_product]=$4
}

/^#svrinfo-   ".*": {\s*$/ {
    svrinfo_category=gensub(/[":]/,"","g",$2)
}

/^#svrinfo-     ".*": [[]\s*$/ {
    svrinfo_group=gensub(/^#svrinfo-\s*"(.*)":.*/,"\\1",1,$0)
    svrinfo_index=0
}

/^#svrinfo-       {\s*/ {
    svrinfo_index=svrinfo_index+1
}

/^#svrinfo-         ".*": ".*",*\s*$/ {
    k=gensub(/^#svrinfo-\s*"(.*)": ".*".*/,"\\1",1,$0)
    v=gensub(/^#svrinfo-\s*".*": "(.*)".*/,"\\1",1,$0)
    svrinfo_values[svrinfo_ws][svrinfo_product][svrinfo_ip][svrinfo_category][svrinfo_group][svrinfo_index][k]=v
    #print "svrinfo_values["svrinfo_ws"]["svrinfo_product"]["svrinfo_ip"]["svrinfo_category"]["svrinfo_group"]["svrinfo_index"]["k"]="v > "/dev/stderr"
}


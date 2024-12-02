#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
    sutinfo_ws="default"
    sutinfo_product="default"
}

/^#sutinfo: / {
    sutinfo_ws=gensub("^.*logs-([^/]*)[/].*$","\\1",1,$2)
    sutinfo_tc=gensub("^.*[/]([^/]*logs-[^/]*)[/].*$","\\1",1,$2)
    sutinfo_ip=gensub("^.*/(.*).json$","\\1",1,$2)
    sutinfo_product=$3
    sutinfo_phostip[sutinfo_ws][sutinfo_product]=$4
    sutinfo_phostip[sutinfo_tc][sutinfo_product]=$4
    sutinfo_category=""
}

/^#sutinfo-   ".*": {\s*$/ {
    sutinfo_category=gensub(/[":]/,"","g",$2)
}

/^#sutinfo-     ".*": [[]\s*$/ {
    sutinfo_group=gensub(/^#sutinfo-\s*"(.*)":.*/,"\\1",1,$0)
    sutinfo_index=0
}

/^#sutinfo-       {\s*/ {
    sutinfo_index=sutinfo_index+1
}

/^#sutinfo-         ".*": ".*",*\s*$/ {
    k=gensub(/^#sutinfo-\s*"(.*)": ".*".*/,"\\1",1,$0)
    v=gensub(/^#sutinfo-\s*".*": "(.*)".*/,"\\1",1,$0)
    sutinfo_values[sutinfo_ws][sutinfo_product][sutinfo_ip][sutinfo_category][sutinfo_group][sutinfo_index][k]=v
    sutinfo_values[sutinfo_tc][sutinfo_product][sutinfo_ip][sutinfo_category][sutinfo_group][sutinfo_index][k]=v
}

# perfspect
/^#sutinfo-  ".*": [[]\s*$/ {
    sutinfo_category="perfspect"
    sutinfo_group=gensub(/^#sutinfo-\s*"(.*)":.*/,"\\1",1,$0)
    sutinfo_index=0
}

# perfspect
/^#sutinfo-   {\s*/ {
    sutinfo_index=sutinfo_index+1
}

# perfspect
/^#sutinfo-    ".*": ".*",*\s*$/ {
    k=gensub(/^#sutinfo-\s*"(.*)": ".*".*/,"\\1",1,$0)
    v=gensub(/^#sutinfo-\s*".*": "(.*)".*/,"\\1",1,$0)
    sutinfo_values[sutinfo_ws][sutinfo_product][sutinfo_ip][sutinfo_category][sutinfo_group][sutinfo_index][k]=v
    sutinfo_values[sutinfo_tc][sutinfo_product][sutinfo_ip][sutinfo_category][sutinfo_group][sutinfo_index][k]=v
}

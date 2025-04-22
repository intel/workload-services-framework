#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

/^#logsdir: / {
    sutinfo_tc="default"
    sutinfo_host="default"
}

/^#sutinfo: / {
    nc=split($2,fields,"/")
    for(i=3;i<=nc-1;i++)
      if(fields[i]~/logs-/) break
    sutinfo_tc=fields[i]
    sutinfo_host=gensub(/[-](svrinfo|sutinfo)$/,"",1,fields[i+1])
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
    sutinfo_values[sutinfo_tc][sutinfo_host][sutinfo_category][sutinfo_group][sutinfo_index][k]=v
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
    sutinfo_values[sutinfo_tc][sutinfo_host][sutinfo_category][sutinfo_group][sutinfo_index][k]=v
}

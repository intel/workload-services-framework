#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The kpi.sh must be self-contained (without using any external script with the 
# exception of commonly available shell scripts and gawk). 

# The kpi.sh script can take arguments, defined by SCRIPT_ARGS in validate.sh. 
# See doc/kpi.sh.md and doc/validate.sh.md for full documentation. 
SCALE=${1:-1}

awk -v scale=$SCALE '
/START-ROI-[0-9]*/ {
    roi=gensub(/START-ROI-/,"",1,$1)
}

/real/ {
    if ($2*1 != 0) throughput[roi]=scale/$2
    real[roi]=$2
}

/user/ || /real/ || /sys/ {
    time[roi]=time[roi]+$2
}

# The kpi.sh must output KPIs in the format of "key: value" or "key (unit): value". 
# The key string must not contain "," or ":". The value must be an integer or a float.
#
# For each test case, define a primary KPI for regression tracking. Prefix the
# primary KPI with "*". There should be 1 and only 1 primary KPI for each test case.
#
# You can add comments after the KPI value. They will show up as tooltips in UI.

END {
    primary="*"
    for(i=1;i<=roi;i++) {
        print "time-"i" (s): "time[i]"     # time for roi-"i
        print primary"throughput-"i" (digits/s): "throughput[i]"     # throughput for roi-"i
        primary=""
    }
}
    

# The kpi.sh parses the workload validation logs at a sub-directory (relative to the 
# current directory.) For example, with the docker backend, the logs are saved under 
# <container-id>, and with the Kubernetes backend, the logs are saved under <pod-id>.  
' */output.logs 2>/dev/null

# The kpi.sh must exit with status 0. Avoid using "exit 0" as the kpi script might 
# be copied to be within a shell script as functions.
true

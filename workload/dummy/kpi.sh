#!/bin/bash

# The kpi.sh must be self-contained (without using any external script with the 
# exception of commonly available shell scripts and gawk). 

# The kpi.sh script can take arguments, defined by SCRIPT_ARGS in validate.sh. 
# See doc/kpi.sh.md and doc/validate.sh.md for full documentation. 
SCALE=${SCALE:-1}

awk -v scale=$SCALE '
# The kpi.sh must output KPIs in the format of "key: value" or "key (unit): value". 
# The key string must not contain "," or ":". The value must be an integer or a float.

/real/ {
    # For each test case, define a primary KPI for regression tracking. Prefix the
    # primary KPI with "*". There should be 1 and only 1 primary KPI for each test case.
    print "*throughput (digits/s): "(scale/$2)
}

# The kpi.sh parses the workload validation logs at a sub-directory (relative to the 
# current directory.) For example, with the docker backend, the logs are saved under 
# <container-id>, and with the Kubernetes backend, the logs are saved under <pod-id>.  
' */output.logs 2>/dev/null

# The kpi.sh must exit with status 0 so that `make kpi` can continue for all workloads. 
# avoid using "exit 0" as the kpi script might be copied to be within a shell script as 
# functions.
echo -n ""

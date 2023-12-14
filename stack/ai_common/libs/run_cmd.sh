#! /bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/info.sh

if [ "$FUNCTION" == "training" ] || [ "$MODE" == "accuracy" ]; then
    exec_node_number=1
else
    exec_node_number=$NUMA_NODES
fi

if [ "${CORES_PER_NUMA}" -lt "${CORES_PER_INSTANCE}" ]; then
    echo "Warning: the number of cores per instance: ${CORES_PER_INSTANCE} exceeds the number of cores per numa: ${CORES_PER_NUMA}"
    CORES_PER_INSTANCE=${CORES_PER_NUMA}
    instance_per_numa=$(expr ${CORES_PER_NUMA} \/ ${CORES_PER_INSTANCE})
else
    instance_per_numa=$(expr ${CORES_PER_NUMA} \/ ${CORES_PER_INSTANCE})
fi

function cal_numa_cores() {
    local instance=$2
    local numa_node=$1

    if [ "$CORES_PER_INSTANCE" == "$CORES_PER_NUMA" ] || [ "$WEIGHT_SHARING" == "True" ]; then
        numa_cores=`lscpu | grep "NUMA node${numa_node} CPU" | awk -F ' ' '{print $4}'`
    else
        numa_offset=$(expr $numa_node \* $CORES_PER_NUMA)
        ht_offset=$(expr $CORES_PER_NUMA \* $NUMA_NODES)
        cores_1=$(expr $(expr $instance \* $CORES_PER_INSTANCE) \+ $numa_offset)
        cores_2=$(expr $(expr $(expr 1 \+ $instance) \* $CORES_PER_INSTANCE) \+ $numa_offset \- 1)
        cores_3=$(expr $cores_1 \+ $ht_offset)
        cores_4=$(expr $cores_2 \+ $ht_offset)
        if [ "$THREADS_PER_CORE" == "1" ]; then
            numa_cores="${cores_1}-${cores_2}"
        else
            numa_cores="${cores_1}-${cores_2},${cores_3}-${cores_4}"
        fi
    fi
    echo "$numa_cores"
}

# Run cmd
# Input: original cmd command
# Output: added numactl cmd command and execute
function run_cmd {
    echo "============ Adding numactl to run cmd ============"
    echo "========================"
    echo " Input cmd: $1 "
    echo "========================"
    BENCH_CMD=$1
    set -x

    for((i=0;i<${exec_node_number};i++))
    do
        for((j=0;j<${instance_per_numa};j++))
        do
            cores=$(cal_numa_cores $i $j)
            numactl --physcpubind=${cores} -m ${i} ${BENCH_CMD} &
        done
    done
}

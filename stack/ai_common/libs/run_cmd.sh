#! /bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/info.sh

# total instance and instance per numa
if [ "$MODE" == "accuracy" ] || [ "$FUNCTION" == "training" ];then
    instance_per_numa=1
    total_instance=1
else
    instance_per_numa=$(expr ${TOTAL_CORES} \/ ${INSTANCE_NUMA})
    total_instance=$(expr ${TOTAL_CORES} \/ ${CORES_PER_INSTANCE})
fi

function cal_numa_cores() {
    local instance=$1
    core_1=$(expr ${instance} \* ${CORES_PER_INSTANCE})
    core_2=$(expr $(expr $(expr 1 \+ ${instance}) \* ${CORES_PER_INSTANCE}) \- 1)
    numa_cores="$core_1-$core_2"
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
    node=0
    for((i=0;i<${total_instance};i++))
    do
        cores=$(cal_numa_cores $i)
        if [ $i == $instance_per_numa ]; then
            let "node+=1"
        fi
        numactl --physcpubind=$cores -m ${node} ${BENCH_CMD} &
    done
}

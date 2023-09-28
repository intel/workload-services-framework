#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# set defaults
RUNMODE=${RUNMODE:-estimated}
BENCHMARK=${BENCHMARK:-intrate}
PLATFORM1=${PLATFORM1:-core-avx512}
COMPILER=${COMPILER:-ic2023.0-lin}
RELEASE1=${RELEASE1:-20221201_intel}
TUNE=${TUNE:-base}
NUMA1=$NUMA
speccpu_config_file=

. ./shrc
. ./numa-detection.sh

b=$(rm -f topo.txt && specperl nhmtopology.pl && cat topo.txt)
c=$(cat /proc/cpuinfo | grep processor | wc -l)
OPTIONS="--nobuild --action validate --define default-platform-flags --define cores=$c --define $b --define smt-on --tune $TUNE -o all --define drop_caches --output_format=all --size ref -I $OPTIONS"

if [ "$RUNMODE" = "estimated" ]; then
    OPTIONS="-n ${ITERATION} --noreportable $OPTIONS"
else
    OPTIONS="--reportable $OPTIONS"
fi

case $BENCHMARK in
intspeed)
    speccpu_config_file=$COMPILER-$PLATFORM1-speed-${RELEASE1}.cfg
    OPTIONS="--copies ${COPIES:-1} --define intspeedaffinity -c $speccpu_config_file $OPTIONS"
    ;;
fpspeed)
    speccpu_config_file=$COMPILER-$PLATFORM1-speed-${RELEASE1}.cfg
    OPTIONS="--copies ${COPIES:-1} -c $speccpu_config_file $OPTIONS"
    ;;
*rate)
    speccpu_config_file=$COMPILER-$PLATFORM1-rate-${RELEASE1}.cfg
    OPTIONS="--copies ${COPIES:-$(nproc)} -c $speccpu_config_file $OPTIONS"
    ;;
6*)
    speccpu_config_file=$COMPILER-$PLATFORM1-speed-${RELEASE1}.cfg
    OPTIONS="--copies ${COPIES:-1} -c $speccpu_config_file $OPTIONS"
    ;;
5*)
    speccpu_config_file=$COMPILER-$PLATFORM1-rate-${RELEASE1}.cfg
    OPTIONS="--copies ${COPIES:-$(nproc)} -c $speccpu_config_file $OPTIONS"
    ;;
esac

ARGS="${ARGS//,/ }"
OPTIONS="$OPTIONS $ARGS"

echo "****************************************************************"
echo Running $OPTIONS
echo "****************************************************************"
ulimit -s unlimited
sync; echo 3> /proc/sys/vm/drop_caches

NUMA=${NUMA1:-$NUMA}
if [[ $NUMA -eq 0 ]]; then
    runcpu $OPTIONS --define no-numa -I $BENCHMARK
else
    if [[ -n "$CPU_NODE" ]]; then
        echo "numactl bind to $CPU_NODE only. Running on numactl --cpunodebind=$CPU_NODE"
        numactl --cpunodebind=$CPU_NODE runcpu $OPTIONS -I $BENCHMARK
    else
        echo "numactl bind to default --interleave=all"
        numactl --interleave=all runcpu $OPTIONS --define invoke_with_interleave -I $BENCHMARK
    fi
fi

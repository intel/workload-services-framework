#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ARGS="$@"

function get_numa_cmd() {
    NUMACTL_OPTIONS=$(eval echo ${K_NUMACTL_OPTIONS})
    if [[ -n $NUMACTL_OPTIONS ]]; then
        echo "numactl ${NUMACTL_OPTIONS}"
        echo "numactl enable" >&2
    else
        echo "numactl not enable" >&2
    fi
}

cd ./byte-unixbench/UnixBench

echo "Start Test"
if [[ ${K_TEST_CASES} == "allinone" ]]; then
    K_TEST_CASES=""
fi
echo "test case: $K_TEST_CASES"
if [[ ${NUMA_ENABLE} == "true" ]]; then
    ./Run
else
    $(get_numa_cmd) ./Run -i ${K_ITERATION_COUNT} -c ${K_PARALLEL_COUNT} ${K_TEST_CASES}
fi

echo "Test completed successfully"
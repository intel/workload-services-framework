#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ulimit -n 65536
DIR=$(dirname $(readlink -f "$0"))
wrk=${2:-$DIR/../../wrk-llnw/wrk}
url=${1:-http://192.168.1.200:8080}
maxconns=${3:-12000}
ncpus=$(grep processor /proc/cpuinfo | wc -l)

for c in $(seq 100 500 ${maxconns}); do
    for t in $(eval echo \"{2..$ncpus..5}\"); do
       if [ $c -lt $t ]; then
           continue
       fi
       echo "THREAD $t CONNECTION $c URL $url:"
       $wrk -t $t -c $c -d 30s --timeout 10s $url/k/k/k
    done
done


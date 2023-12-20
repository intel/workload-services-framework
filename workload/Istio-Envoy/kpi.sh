#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

path=$(find . -name performance.log)

string_to_num() {
   input=$1
   times=($input)
   s=$((10#$(echo ${times[0]} | awk -F 's' '{print $1}')))
   ms=$((10#$(echo ${times[1]} | awk -F 'ms' '{print $1}')))
   us=$(echo ${times[2]} | awk -F 'us' '{print $1}')
   integer=$((s*1000 + ms))
   printf "%s.%s\n" "$integer" "$us"
}

achieved_RPS=$(cat $path | grep benchmark.http_2xx | awk '{print $3}')
P90=$(cat $path | grep ' 0\.9 ' | tail -n1 | xargs | cut -d ' ' -f3-)
P99=$(cat $path | grep ' 0\.990' | tail -n1 | xargs | cut -d ' ' -f3-)
P999=$(cat $path | grep ' 0\.9990' | tail -n1 | xargs | cut -d ' ' -f3-)

P90=$(string_to_num "$P90")
P99=$(string_to_num "$P99")
P999=$(string_to_num "$P999")

printf "*Requests(Per Second): %s\n" "$achieved_RPS"
printf "LatencyP90(ms): %s\n" "$P90"
printf "LatencyP99(ms): %s\n" "$P99"
printf "LatencyP999(ms): %s\n" "$P999"

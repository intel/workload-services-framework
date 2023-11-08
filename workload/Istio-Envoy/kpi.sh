#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

path=$(find . -name performance.log)

achieved_RPS=$(cat $path | grep benchmark.http_2xx | awk '{print $3}')
P90=$(cat $path | grep ' 0\.9 ' | tail -n1 | xargs | cut -d ' ' -f3-)
P99=$(cat $path | grep ' 0\.990' | tail -n1 | xargs | cut -d ' ' -f3-)
P999=$(cat $path | grep ' 0\.9990' | tail -n1 | xargs | cut -d ' ' -f3-)

printf "*Requests(Per Second): %s\n" "$achieved_RPS"
printf "Latency9: %s\n" "$P90"
printf "Latency99: %s\n" "$P99"
printf "Latency999: %s\n" "$P999"
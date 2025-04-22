#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Siege will always use interleave=all
# Replace back replace holder ? to space for arguments
SIEGE_NUMA_OPTIONS=${SIEGE_NUMA_OPTIONS//"?"/" "}
SIEGE_NUMA_OPTIONS=${SIEGE_NUMA_OPTIONS//"!"/","}
echo "SIEGE_NUMA_OPTIONS: ${SIEGE_NUMA_OPTIONS}"

# Wait for all nginx and wordpress are ok
max_index=$((INSTANCE_COUNT - 1))
max_retry_count=600
retry_count=1

for i in $(seq 0 $max_index); do
    port=$((NGINX_BASE_PORT + $i))
    if [[ $HTTPMODE == "http" ]]; then
        url="http://siteurl-${i}:${port}"
    else
        url="https://siteurl-${i}:${port}"
    fi
    while [ $(curl -k -sw '%{http_code}' -m 5 "$url" -o /dev/null) -ne 200 ]; do
        echo "Waiting for $url, time $retry_count"
        sleep 1s
        ((retry_count++))
        if [[ "$retry_count" -ge "$max_retry_count" ]]; then
            echo "Error: Failed to get connected to $url! Test failed."
            exit 3
        fi
    done
    echo "$url is accessible."
done

echo "All siteurls are accessible."

# Generate WordpressTarget.url/urls
touch sum.urls
for i in $(seq 0 $((INSTANCE_COUNT - 1))); do
    #cp sum.urls last_sum.urls
    cp WordpressTarget.url $i.urls
    port=$((NGINX_BASE_PORT + $i))
    if [[ $HTTPMODE == "http" ]]; then
        sed -i 's|http://__HTTP_HOST__:__HTTP_PORT__|'http://siteurl-$i:$port'|g' /$i.urls
    else
        sed -i 's|http://__HTTP_HOST__:__HTTP_PORT__|'https://siteurl-$i:$port'|g' /$i.urls
    fi
    cat $i.urls >> sum.urls
done

cp sum.urls WordpressTarget.urls

#tail -f /var/log/syslog > siege_syslog.log &

numactl $SIEGE_NUMA_OPTIONS /siege-script.sh
#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

rm -rf /var/lib/postgresql/data/*

source /create_mapping.sh
if [ -n "$CLIENT_0_HOST" ]; then # 2 nodes scenario
    if [ "$SERVER_SOCKET_BIND_NODE" -eq 0 ]; then
        start_tid=0
    elif [ "$SERVER_SOCKET_BIND_NODE" -eq 1 ]; then
        start_tid=$cores_per_socket
    else
        echo "Please set valid SERVER_SOCKET_BIND_NODE, either 0 or 1"
        exit 1
    fi
else # 1 node scenario
    start_tid=0 
fi
instance_id=$DB_INDEX
core_mappings $start_tid $instance_id $SERVER_CORES_PI
NUMACTL_OPTIONS="numactl --cpunodebind=$numa_id --membind=$numa_id --physcpubind=$instance_cores"
echo "NUMACTL_OPTIONS for postgres instance $instance_id: $NUMACTL_OPTIONS"

# exec numactl --cpunodebind=0 --membind=0 --physcpubind=1,2,3,4 "$@"
### Replace "exec postgres" with "exec numactl ... postgres" to bind postgres process with numactl
sed -i "s#exec "$@"#exec $NUMACTL_OPTIONS "$@"#" /usr/local/bin/docker-entrypoint.sh    

sed -i "s/HUGE_PAGES_STATUS/$HUGE_PAGES_STATUS/" /etc/postgresql.conf

/usr/local/bin/docker-entrypoint.sh postgres -p $DB_PORT -c config_file=/etc/postgresql.conf


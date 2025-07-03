#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This script is called when the cassandra image is built
# It receives the hostname as a parameter (cassandra)

HOSTNAME=$1
# Settings for 2-socket Broadwell-EP with 22 cores per socket,
# all services running on same machine
sed -i "s/seeds: \"127.0.0.1/seeds: \"$HOSTNAME/" /etc/cassandra/cassandra.yaml
sed -e "s/seeds: \"127.0.0.1\"/seeds: \"$HOSTNAME\"/g"                                         \
    -e "s/rpc_address: localhost/rpc_address: 0.0.0.0/g"                                     \
    -e "s/# broadcast_address: 1.2.3.4/broadcast_address: $HOSTNAME/g"                                     \
    -e "s/# broadcast_rpc_address: 1.2.3.4/broadcast_rpc_address: $HOSTNAME/g"                                     \
    -e "s/concurrent_reads: 32/concurrent_reads: $CASSANDRA_CR/g"                                         \
    -e "s/concurrent_writes: 32/concurrent_writes: $CASSANDRA_CW/g"                                      \
    -e "s/concurrent_counter_writes: 32/concurrent_counter_writes: $CASSANDRA_CCW/g"                      \
    -e "s/concurrent_materialized_view_writes: 32/# concurrent_materialized_view_writes: 32/g" \
    -i /etc/cassandra/cassandra.yaml

sysctl -p

service cassandra start && tail -f /dev/null

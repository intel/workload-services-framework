#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#note: suggest to let cores_per_numa divisible by cores_per_instance; otherwise some instance will cross numa.
numa=$(lscpu | awk '/^NUMA node\(s\)/{print $3}')
sockets=$(lscpu | awk '/Socket\(s\)/{print $NF}')
cpus=$(lscpu | awk '/^CPU\(s\):/{print $NF}')
numa_per_socket=$((numa/sockets))
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
cores_per_numa=$((cores_per_socket/numa_per_socket))


# generate core mapping list
# in single node scenario: start_tid is 0 for server
# in single node scenario: start_tid is cores_per_socket for client
# in 2 nodes scenario: start_tid is decided by users with SERVER_SOCKET_BIND_NODE & CLIENT_SOCKET_BIND_NODE
core_mappings(){
    start_tid=$1
    instance_id=$2
    cores_per_instance=$3
    id_0=$((start_tid+cores_per_instance*instance_id))
    id_1=$((id_0+cores_per_instance-1))
    numa_id=$((id_0/cores_per_numa))
    if [ "$threads_per_core" -eq 2 ]; then
        id_2=$(($((sockets*cores_per_socket))+$id_0))
        id_3=$((id_2+cores_per_instance-1))
        instance_cores=$id_0"-"$id_1","$id_2"-"$id_3
        if [ "$id_3" -gt "$((cpus-1))" ]; then
            echo "instance $instance_id Error: CPU $id_3 is greater than mamixmum CPUs, can't bind to a CPU doesn't exist"
            exit 1
        fi
    elif [ "$threads_per_core" -eq 1 ]; then
        instance_cores=$id_0"-"$id_1
        if [ "$id_1" -gt "$((cpus-1))" ]; then
            echo "instance $instance_id Error: CPU $id_1 is greater than mamixmum CPUs, can't bind to a CPU doesn't exist"
            exit 1
        fi
    fi
}

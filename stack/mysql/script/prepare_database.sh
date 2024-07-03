#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [[ "$DB_TYPE" == "mysql" ]]; then
    mkdir -p "$MYSQL_LOG_DIR"
    chown -R mysql:mysql "$MYSQL_LOG_DIR"
    echo "MySQL log directory $MYSQL_LOG_DIR created"
fi

# auto cleanup mounted data
if ${ENABLE_MOUNT_DIR:-false}; then
    echo "Remove database directory $DB_MOUNT_DIR"
    rm -rf "${DB_MOUNT_DIR:?}/"*
fi

### numactl bind core logic
lscpu -p=CPU,NODE|sed -e '/^#/d' > /tmp/cpu_numa_map
NUMACTL_OPTIONS=""
if ${RUN_SINGLE_NODE:-true}; then
    # on single node
    if ${ENABLE_SOCKET_BIND:-true}; then
        if [[ -z "$SERVER_SOCKET_BIND_NODE" ]]; then
            system_cores=$(nproc)
            if [[ "$system_cores" -le 1 ]]; then
                echo "Only $system_cores cores, skip to balance"
            else
                nodes=$(lscpu | awk '/^NUMA node\(s\)/{print $3'})
                SERVER_CORE_NEEDED_FACTOR=${SERVER_CORE_NEEDED_FACTOR:-0.9}
                SERVER_CORE_NEEDED=$(echo "$system_cores $SERVER_CORE_NEEDED_FACTOR" |awk '{ printf("%d\n",$1 * $2) }')
                CLIENT_CORE_NEEDED=$((system_cores - SERVER_CORE_NEEDED))
                CLIENT_CORE_NEEDED_LESS=true # assume client need less core
                if [[ "$CLIENT_CORE_NEEDED" -gt "$SERVER_CORE_NEEDED" ]]; then
                    CLIENT_CORE_NEEDED_LESS=false
                fi
                # caculate which cores will be used
                HALF_SYSTEM_CORES=$(( system_cores / 2 ))
                for i in $(seq 0 $((HALF_SYSTEM_CORES - 1)))
                do
                    if [[ !$CLIENT_CORE_NEEDED_LESS && "$i" -ge "$SERVER_CORE_NEEDED" ]]; then
                        break
                    fi
                    nth_core_on_node=$(((2 * (i / nodes)) + 1))
                    core=$(grep ",$((i % nodes))" /tmp/cpu_numa_map | sed "${nth_core_on_node}q;d" | awk -F ',' '{print $1}')
                    core_list+=($core)
                    if [[ $CLIENT_CORE_NEEDED_LESS && "$i" -ge "$CLIENT_CORE_NEEDED" ]]; then
                        core_list+=($((core+1))) # assign client leftover cores to server
                    fi
                done
                echo "Run on single node, system online cores: $system_cores, numa nodes: $nodes, server core needed factor: $SERVER_CORE_NEEDED_FACTOR, server core needed: ${#core_list[@]}, client core needed: $CLIENT_CORE_NEEDED"
                NUMACTL_OPTIONS="numactl --physcpubind=$(echo ${core_list[@]}|tr ' ' ',') --localalloc"
            fi
        else
            if [[ -z "$SERVER_SOCKET_BIND_CORE_LIST" ]]; then
                NUMACTL_OPTIONS="numactl --cpunodebind=$SERVER_SOCKET_BIND_NODE --membind=$SERVER_SOCKET_BIND_NODE"
                echo "Run on multi node, socket bind enabled, bind on nodes: $SERVER_SOCKET_BIND_NODE"
            else
                NUMACTL_OPTIONS="numactl --cpunodebind=$SERVER_SOCKET_BIND_NODE --membind=$SERVER_SOCKET_BIND_NODE --physcpubind=$SERVER_SOCKET_BIND_CORE_LIST"
                echo "Run on multi node, socket bind enabled, bind on nodes: $SERVER_SOCKET_BIND_NODE, bind on cpu list: $SERVER_SOCKET_BIND_CORE_LIST"
            fi
        fi
    else
        echo "Run on single node, socket bind disabled, skip to bind"
    fi
else
    if ${ENABLE_SOCKET_BIND:-true}; then
        DEFAULT_NODES=$(lscpu |awk '/^NUMA node[0-9]+ CPU\(s\)/{split($2, result, "node"); print result[2]}' |tr '\n' ',')
        if [[ "${DEFAULT_NODES}" =~ ^.*,$ ]]; then
            DEFAULT_NODES=${DEFAULT_NODES::-1} # remove the last character ","
        fi
        if [[ -z "$SERVER_SOCKET_BIND_NODE" ]]; then
            echo "Not specified socket bind node, by default using all nodes $DEFAULT_NODES"
            SERVER_SOCKET_BIND_NODE=$DEFAULT_NODES
        fi
        if ${EXCLUDE_IRQ_CORES:-true}; then
            function get_network_device_by_ip() {
                node_ip=$1
                ALL_NETWORK_DEVICES=($(ls /sys/class/net))
                for dev in "${ALL_NETWORK_DEVICES[@]}"
                do
                    output=$(ifconfig $dev)
                    if [[ "$output" =~ "$node_ip" ]]; then
                        rtn_net_dev=$dev # device found by node ip
                        break
                    fi
                done
                echo "$rtn_net_dev"
            }
            NET_DEV=$(get_network_device_by_ip $NODE_IP)
            file1=/tmp/node_cores
            file2=/tmp/irq_cores
            irq_cores=()
            for i in $(cat /proc/interrupts |grep "$NET_DEV" |awk -F ':' '{print $1}')
            do 
                irq_cores+=($(cat /proc/irq/$i/smp_affinity_list))
            done
            echo "irq_cores: ${irq_cores[@]}"
            echo "${irq_cores[@]}" |tr ' ' '\n' > $file2

            nodes=($(echo $SERVER_SOCKET_BIND_NODE |tr '_\|,' ' ')) #split by _ or ,
            for node in ${nodes[@]}
            do
                node_cores+=($(grep ",$node" /tmp/cpu_numa_map | awk -F ',' '{print $1}'))
            done
            echo "node_cores: ${node_cores[@]}"
            echo "${node_cores[@]}" |tr ' ' '\n' >  $file1
            
            # file1 - file2
            app_cores=$(sort -m <(sort $file1 | uniq) <(sort $file2 | uniq) <(sort $file2 | uniq) | uniq -u |sort -n|tr '\n' ',')
            if [[ "${app_cores}" =~ ^.*,$ ]]; then
                app_cores=${app_cores::-1} # remove the last character ","
            fi
            echo "app_cores: $app_cores"
            NUMACTL_OPTIONS="numactl --physcpubind=$app_cores --localalloc"
            echo "Run on multi node, socket bind enabled, bind on cores exclude interrupt cores"
        else
            if [[ -z "$SERVER_SOCKET_BIND_CORE_LIST" ]]; then
                NUMACTL_OPTIONS="numactl --cpunodebind=$SERVER_SOCKET_BIND_NODE --membind=$SERVER_SOCKET_BIND_NODE"
                echo "Run on multi node, socket bind enabled, bind on nodes: $SERVER_SOCKET_BIND_NODE"
            else
                NUMACTL_OPTIONS="numactl --cpunodebind=$SERVER_SOCKET_BIND_NODE --membind=$SERVER_SOCKET_BIND_NODE --physcpubind=$SERVER_SOCKET_BIND_CORE_LIST"
                echo "Run on multi node, socket bind enabled, bind on nodes: $SERVER_SOCKET_BIND_NODE, bind on cpu list: $SERVER_SOCKET_BIND_CORE_LIST"
            fi
        fi
    else
        echo "Run on multi node, socket bind disabled, skip to bind"
    fi
fi
echo "NUMACTL_OPTIONS: $NUMACTL_OPTIONS"
### end numactl bind core logic

### Replace "exec mysqld" with "exec numactl ... mysqld" to bind mysqld process with numactl
sed -i "s#exec "$@"#exec $NUMACTL_OPTIONS "$@"#" /usr/local/bin/docker-entrypoint.sh

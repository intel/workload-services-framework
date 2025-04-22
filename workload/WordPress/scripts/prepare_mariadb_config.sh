#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
MARIADB_NUMA_OPTIONS_THIS_INSTANCE=""
echo "nginx host: $NGINX_HOST"
echo "nginx port: $NGINX_PORT"

function get_all_cpu_pinning() {
    sockets_num=$(lscpu | grep "Socket(s):" | sed "s/.* //g")

    for cpu in $(ls -d /sys/devices/system/cpu/cpu[0-9]* | sort -t u -k 3 -n); do
        socket_id=$(cat $cpu/topology/physical_package_id)
        tmp_name=cpusets_socket${socket_id}
        declare ${tmp_name}+=$(cat $cpu/topology/thread_siblings_list)" "
    done
    cpu_pinning_s=()
    count_per_socket=$((INSTANCE_COUNT / sockets_num))

    for ((socket_id = 0; socket_id < ${sockets_num}; socket_id++)); do
        tmp_name=cpusets_socket${socket_id}
        all_cpus=($(echo ${!tmp_name} | tr ' ' '\n' | cat -n | sort -uk2 | sort -n | cut -f2- | tr '\n' ' '))
        if [[ ${socket_id} -eq $((${sockets_num} - 1)) ]]; then
            count_per_socket=$(($count_per_socket + $INSTANCE_COUNT % $sockets_num))
        fi
        cpu_per_instance=$((${#all_cpus[@]} / $count_per_socket))
        start=0
        for ((i = 1; i <= $count_per_socket; i++)); do
            if [[ ${i} -eq $count_per_socket ]]; then
                array=("${all_cpus[@]:${start}}")
            else
                array=("${all_cpus[@]:${start}:${cpu_per_instance}}")
            fi
            start=$((start + cpu_per_instance))
            cpuset_cpus_s=$(printf ",%s" "${array[@]}")
            cpuset_cpus_s=${cpuset_cpus_s:1}

            numa_run_s="-C "${cpuset_cpus_s}" --localalloc"
	    cpu_pinning_s+=("$numa_run_s")
        done
    done
}

function split_cpulist() {
    local cpulist=$1
    local count=$2
    local start=$(echo "$cpulist" | cut -d'-' -f1)
    local end=$(echo "$cpulist" | cut -d'-' -f2)
    if [ "$count" -gt "$((end - start + 1))" ]; then
        for ((i = 0; i < $count; i++)); do
            partitions+=("$cpulist")
        done
    else
        local step=$(( ($end - $start + 1) / count ))
        local partitions=()
        for ((i = 0; i < $count; i++)); do
                range_start=$(( $start + $i * $step ))
                range_end=$(( $range_start + $step - 1))
                partitions+=("$range_start-$range_end")
        done
    fi
    echo "${partitions[@]}"
}

function get_partial_cpu_pinning() {
    numa_options=$1 # MARIADB_NUMA_OPTIONS
    count=$2
    cpuslist_str=$(echo "${numa_options}" | awk -F '-C ' '{print $2}' | awk '{print $1}')
    total_cpu_list=$(echo "$cpuslist_str" | awk -F ',' '{print NF}')
    IFS=',' read -r -a cpu_list_array <<< "$cpuslist_str"
    splist=()
    for ((i = 0; i < $total_cpu_list; i++)); do
        splited_cpuslist=($(split_cpulist "${cpu_list_array[$i]}" $count))
        for ((j = 0; j < $count; j++)); do
           splist[$j]+="${splited_cpuslist[$j]}"
           if (( i < total_cpu_list - 1 )); then
                splist[$j]+=","
           fi
        done
    done
    local merged_cpuslist=()
    for ((j = 0; j < $count; j++)); do
        merged_cpuslist+=("${splist[j]}")
    done
    echo "${merged_cpuslist[@]}"
}

function reset_siteurl_in_database() {
    if [[ $HTTPMODE == "http" ]];then
        gunzip -c /dbdump.sql.gz | sed -e "s|'use_ssl','0'|'use_ssl','0'|g" > /docker-entrypoint-initdb.d/dbdump.sql
        sed -i "s|'siteurl','http://siteurl'|'siteurl','http://$NGINX_HOST:$NGINX_PORT'|g" /docker-entrypoint-initdb.d/dbdump.sql
        sed -i "s|'home','http://siteurl'|'home','http://$NGINX_HOST:$NGINX_PORT'|g" /docker-entrypoint-initdb.d/dbdump.sql
    else
        gunzip -c /dbdump.sql.gz | sed -e "s|'use_ssl','0'|'use_ssl','1'|g" > /docker-entrypoint-initdb.d/dbdump.sql
        sed -i "s|'siteurl','http://siteurl'|'siteurl','https://$NGINX_HOST:$NGINX_PORT'|g" /docker-entrypoint-initdb.d/dbdump.sql
        sed -i "s|'home','http://siteurl'|'home','https://$NGINX_HOST:$NGINX_PORT'|g" /docker-entrypoint-initdb.d/dbdump.sql
	#sed -i "s|'permalink_structure','/%year%/%monthnum%/%day%/%postname%/'|'permalink_structure',''|g" /docker-entrypoint-initdb.d/dbdump.sql
    fi
    sed -i "s|'permalink_structure','/%year%/%monthnum%/%day%/%postname%/'|'permalink_structure',''|g" /docker-entrypoint-initdb.d/dbdump.sql
}

function numa_mariadb() {
    if [[ -n "$VCPUS_PER_INSTANCE" && $SUTINFO_CSP == "static" ]]; then
        IFS='_' read -r -a instance_cpus_array <<< "$ALL_INSTANCE_CPU_STR"
        MARIADB_NUMA_OPTIONS_THIS_INSTANCE="-C ${instance_cpus_array[$BENCHMARK_ID]} --localalloc"
    elif [[ $MARIADB_NUMA_OPTIONS == "--interleave=all" ]];then
        if [[ $INSTANCE_COUNT -gt 1 ]]; then
            get_all_cpu_pinning
            MARIADB_NUMA_OPTIONS_THIS_INSTANCE=${cpu_pinning_s[$BENCHMARK_ID]}
        elif [[ $INSTANCE_COUNT -eq 1 ]]; then
            MARIADB_NUMA_OPTIONS_THIS_INSTANCE=$MARIADB_NUMA_OPTIONS
        fi
    else
        # Replace back replace holder ? to space for arguments
        MARIADB_NUMA_OPTIONS=${MARIADB_NUMA_OPTIONS//"?"/" "}
        MARIADB_NUMA_OPTIONS=${MARIADB_NUMA_OPTIONS//"!"/","}
        if [[ $INSTANCE_COUNT -gt 1 ]]; then
            partial_cpu_pinning_s=($(get_partial_cpu_pinning "$MARIADB_NUMA_OPTIONS" $INSTANCE_COUNT))
            MARIADB_NUMA_OPTIONS_THIS_INSTANCE="-C ${partial_cpu_pinning_s[$BENCHMARK_ID]} --localalloc"
        elif [[ $INSTANCE_COUNT -eq 1 ]]; then
            MARIADB_NUMA_OPTIONS_THIS_INSTANCE=$MARIADB_NUMA_OPTIONS
        fi
    fi
    echo "MARIADB_NUMA_OPTIONS_THIS_INSTANCE: $MARIADB_NUMA_OPTIONS_THIS_INSTANCE"
    sed -i "s|exec "$@"|exec numactl $MARIADB_NUMA_OPTIONS_THIS_INSTANCE "$@"|" /usr/local/bin/docker-entrypoint.sh
}

# Kernel Configuration
sysctl -w net.ipv4.tcp_tw_reuse=1 || true

sed -i "s|port = 3306|port = $MYSQL_PORT|g" /etc/mysql/my.cnf

reset_siteurl_in_database
numa_mariadb


/usr/local/bin/docker-entrypoint.sh mariadbd

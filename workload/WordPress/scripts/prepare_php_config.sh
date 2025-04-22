#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
PHP_NUMA_OPTIONS_THIS_INSTANCE=""
NSERVERS=${NSERVERS:-auto}

host=$(echo "$WORDPRESS_DB_HOST" | cut -d':' -f1)
port=$(echo "$WORDPRESS_DB_HOST" | cut -d':' -f2)
until nc -z -w10 $host $port ;do echo Waiting...;sleep 1s;done;


function reset_nservers() {
    numa_options=$1 # PHP_NUMA_OPTIONS
    # Replace back replace holder ? to space for arguments
    numa_options=${numa_options//"?"/" "}
    numa_options=${numa_options//"!"/","}
    count=$2    # INSTANCE_COUNT
    php_worker_num_given=$3 # NSERVERS
    php_worker_num_real=0
    core_num=0
    if [ "$php_worker_num_given" == "auto" ]; then
        if [[ "${numa_options}" == *"-C "* ]]; then
            local cpuslist_str=$(echo "${numa_options}" | awk -F '-C ' '{print $2}' | awk '{print $1}')
            local cpuslist_half=$(echo $cpuslist_str | awk -F ',' '{print $1}')
            local start=$(echo "$cpuslist_half" | cut -d'-' -f1)
            local end=$(echo "$cpuslist_half" | cut -d'-' -f2)
            if [ "$count" -gt "$((end - start + 1))" ]; then
                php_worker_num_real=1
            else
                local cpu_num_half=$(( ($end - $start + 1) / count ))
                php_worker_num_real=$((2 * cpu_num_half))
            fi
        fi
        if [[ "${numa_options}" == "--interleave=all" ]]; then
            core_num=$(nproc)
            php_worker_num_real=$((core_num / count))
        fi
    else
        php_worker_num_real=$php_worker_num_given
    fi

    echo "Set pm.max_children = $php_worker_num_real"
    sed -i "s|pm.max_children = 50|pm.max_children = $php_worker_num_real|" /usr/local/etc/php-fpm.d/www.conf
}

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

function numa_php() {
    if [[ -n "$VCPUS_PER_INSTANCE" && $SUTINFO_CSP == "static" ]]; then
        IFS='_' read -r -a instance_cpus_array <<< "$ALL_INSTANCE_CPU_STR"
        PHP_NUMA_OPTIONS_THIS_INSTANCE="-C ${instance_cpus_array[$BENCHMARK_ID]} --localalloc"
    elif [[ $PHP_NUMA_OPTIONS == "--interleave=all" ]];then
        if [[ $INSTANCE_COUNT -gt 1 ]]; then
            get_all_cpu_pinning
            PHP_NUMA_OPTIONS_THIS_INSTANCE=${cpu_pinning_s[$BENCHMARK_ID]}
        elif [[ $INSTANCE_COUNT -eq 1 ]]; then
            PHP_NUMA_OPTIONS_THIS_INSTANCE=$PHP_NUMA_OPTIONS
        fi
    else
        # Replace back replace holder ? to space for arguments
        PHP_NUMA_OPTIONS=${PHP_NUMA_OPTIONS//"?"/" "}
        PHP_NUMA_OPTIONS=${PHP_NUMA_OPTIONS//"!"/","}
        if [[ $INSTANCE_COUNT -gt 1 ]]; then
            partial_cpu_pinning_s=($(get_partial_cpu_pinning "$PHP_NUMA_OPTIONS" $INSTANCE_COUNT))
            PHP_NUMA_OPTIONS_THIS_INSTANCE="-C ${partial_cpu_pinning_s[$BENCHMARK_ID]} --localalloc"
        elif [[ $INSTANCE_COUNT -eq 1 ]]; then
            PHP_NUMA_OPTIONS_THIS_INSTANCE=$PHP_NUMA_OPTIONS
        fi
    fi
    echo "PHP_NUMA_OPTIONS_THIS_INSTANCE: $PHP_NUMA_OPTIONS_THIS_INSTANCE"
    sed -i "s|exec "$@"|exec numactl $PHP_NUMA_OPTIONS_THIS_INSTANCE "$@"|" /usr/local/bin/docker-entrypoint.sh
}

# Kernel Configuration
sysctl -w net.ipv4.tcp_tw_reuse=1 || true
sed -i "s|listen = 9000|listen = $WORDPRESS_PORT|g" /usr/local/etc/php-fpm.d/www.conf
echo "listen = $WORDPRESS_PORT" >> /usr/local/etc/php-fpm.conf
reset_nservers "$PHP_NUMA_OPTIONS" $INSTANCE_COUNT $NSERVERS
numa_php


/usr/local/bin/docker-entrypoint.sh php-fpm;

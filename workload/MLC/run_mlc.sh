#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

MLC_BIN=/mlc/mlc

echo "=== START $(basename "$0")"

DURATION=${DURATION:-5}
ARGS=${ARGS:-""}

echo "*****************************************************************************"
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
total_numa_nodes=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')
physical_cores_per_numa=$((cores_per_socket / total_numa_nodes / total_sockets))
total_cores=$((cores_per_socket * total_sockets))
cores_per_die=$((cores_per_socket / 4))

sd=7
sample_core_count=2

echo "total sockets:       ${total_sockets}"
echo "total cores:         ${total_cores}"
echo "threads/core:        ${threads_per_core}"
echo "cores/socket:        ${cores_per_socket}"
echo "no of numa nodes:    ${total_numa_nodes}"
echo "physical cores/numa: ${physical_cores_per_numa}"
echo "*****************************************************************************"

random_seed() {
    seed=$1
    openssl enc -aes-256-ctr -pass pass:"${seed}" -nosalt </dev/zero 2>/dev/null
}

get_random_core() {
    local start=$1
    local skt=$2
    local seed=$3
    local core=$4
    if [[ ${total_sockets} -gt 2 ]]; then
        echo $((cores_per_socket * skt + 1))
    fi
    if [[ -z ${core} ]]; then
        rnd_core=$(($(shuf -i"${start}"-$((cores_per_die + start - 1)) -n1 --random-source=<(random_seed "$seed")) + cores_per_socket * skt))
    else
        rnd_core=${core}
        multiplier=2
        while [[ ${rnd_core} -eq ${core} ]]; do
            tmp_seed=$((seed * multiplier))
            rnd_core=$(($(shuf -i"${start}"-$((cores_per_die + start - 1)) -n1 --random-source=<(random_seed ${tmp_seed})) + cores_per_socket * skt))
            multiplier=$((multiplier + 1))
        done
    fi
    echo "${rnd_core}"
}

echo "Measuring $TEST"
case "$TEST" in
local_latency)
    for ((i = 0; i < cores_per_socket; i += cores_per_die)); do
        rnd_core1=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        rnd_core2=$rnd_core1
        while [[ $rnd_core1 -eq $rnd_core2 ]]; do
            rnd_core2=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        done
        for core in $rnd_core1 $rnd_core2; do
            ${MLC_BIN} --idle_latency -b2g -x0 -c"$core" -i"$core"
        done
    done
    ;;

local_latency_random)
    for ((i = 0; i < cores_per_socket; i += cores_per_die)); do
        rnd_core1=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        rnd_core2=$rnd_core1
        while [[ $rnd_core1 -eq $rnd_core2 ]]; do
            rnd_core2=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        done
        for core in $rnd_core1 $rnd_core2; do
            ${MLC_BIN} --idle_latency -r -b2g -x0 -c"$core" -i"$core"
        done
    done
    ;;

remote_latency)
    if [ "${total_sockets}" -lt 2 ]; then
        echo -e "\n****Error: Found single socket. Remote Latency can not be calculated ****\n"
        exit
    fi

    for ((i = 0; i < cores_per_socket; i += cores_per_die)); do
        rnd_core1=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        rnd_core2=$rnd_core1
        while [[ $rnd_core1 -eq $rnd_core2 ]]; do
            rnd_core2=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        done
        for core in $rnd_core1 $rnd_core2; do
            ${MLC_BIN} --idle_latency -b2g -x0 -c"$core" -i$((cores_per_socket + core))
        done
    done
    ;;

remote_latency_random)
    if [ "${total_sockets}" -lt 2 ]; then
        echo -e "\n****Error: Found single socket. Remote Latency can not be calculated ****\n"
        exit
    fi

    for ((i = 0; i < cores_per_socket; i += cores_per_die)); do
        rnd_core1=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        rnd_core2=$rnd_core1
        while [[ $rnd_core1 -eq $rnd_core2 ]]; do
            rnd_core2=$(shuf -i$i-$((cores_per_die + i - 1)) -n1)
        done
        for core in $rnd_core1 $rnd_core2; do
            ${MLC_BIN} --idle_latency -r -b2g -x0 -c"$core" -i$((cores_per_socket + core))
        done
    done
    ;;

llc_bandwidth)
    ${MLC_BIN} --loaded_latency -d0 -T -X -b8m -t"${DURATION}" -u
    ;;

local_read_bandwidth)
    if [[ -z $skt ]]; then
        sockets={1..$total_sockets}
    else
        sockets=$((skt + 1))
    fi

    numa_per_socket=$((total_numa_nodes / total_sockets))
    for skt in $(eval echo "$sockets"); do
        for nodes in $(seq $((numa_per_socket * skt - numa_per_socket + 1)) $((numa_per_socket * skt))); do
            numa_nodes=$((nodes - 1))
            numa_cores=$(lscpu | grep "NUMA node$numa_nodes" | awk -F ':' '{print $NF}')
            core=$(echo "$numa_cores" | awk -v node="$nodes" '{print $nodes}')
            echo "$core" R seq 500m dram $((numa_nodes)) >>/tmp/config_"$skt"
        done
        cat /tmp/config_"$skt"
        ${MLC_BIN} --loaded_latency -d0 -T -t"${DURATION}" -o/tmp/config_"$skt"
    done
    ;;

peak_remote_bandwidth)
    if [ "${total_sockets}" -lt 2 ]; then
        echo -e "\n****Error: Found single socket. Peak Remote Bandwidth can not be calculated ****\n"
        exit
    fi

    ${MLC_BIN} --loaded_latency -d0 -T -b500m -t"${DURATION}" -j1 -R -k0-$((cores_per_socket - 1))
    ;;

peak_remote_bandwidth_reverse)
    if [ "${total_sockets}" -lt 2 ]; then
        echo -e "\n****Error: Found single socket. Peak Remote Bandwidth can not be calculated ****\n"
        exit
    fi

    ${MLC_BIN} --loaded_latency -d0 -T -b500m -t"${DURATION}" -j0 -R -k"$cores_per_socket"-$((2 * cores_per_socket - 1))
    ;;

peak_bandwidth_rw_combo_1tpc)
    for n in 1; do
        ${MLC_BIN} --loaded_latency -d0 -X -T -b1g -t"${DURATION}" -R
    done
    for n in 2 3 4 5; do
        ${MLC_BIN} --loaded_latency -d0 -X -T -K1 -b1g -t"${DURATION}" -W$n
    done
    for n in 6 7 8 9 10; do
        ${MLC_BIN} --loaded_latency -d0 -X -T -b1g -t"${DURATION}" -W$n
    done
    ;;

peak_bandwidth_rw_combo_2tpc)
    for n in 1; do
        sync
        echo 3>/proc/sys/vm/drop_caches
        ${MLC_BIN} --loaded_latency -d0 -T -b512m -t"${DURATION}" -R
    done
    for n in 2 3 4 5; do
        sync
        echo 3>/proc/sys/vm/drop_caches
        ${MLC_BIN} --loaded_latency -d0 -T -K1 -b512m -t"${DURATION}" -W$n
    done
    for n in 6 7 8 9 10; do
        sync
        echo 3>/proc/sys/vm/drop_caches
        ${MLC_BIN} --loaded_latency -d0 -T -b512m -t"${DURATION}" -W$n
    done
    ;;

loaded_latency)
    ${MLC_BIN} --loaded_latency
    ;;

local_socket_remote_cluster_memory_latency)
    if [[ ${total_sockets} -gt 2 ]]; then
        sample_core_count=1
    fi

    for ((n = 0; n < total_sockets; n++)); do
        for ((c = 0, k = 0; c < cores_per_socket; c += cores_per_die, k++)); do
            for ((i = 0, j = 0; i < cores_per_socket; i += cores_per_die, j++)); do
                if [[ $k -eq $j ]]; then
                    continue
                fi
                for ((r = 1; r <= sample_core_count; r++)); do
                    IFS= read -r rnd_core1 < <(get_random_core $c $n $((sd + r)))
                    IFS= read -r rnd_core2 < <(get_random_core $i $n $((sd + r)))
                    cmd="--idle_latency -b2g -x0 -c$rnd_core1 -i$rnd_core2"
                    ${MLC_BIN} ${cmd}
                done
            done
        done
    done
    ;;

local_socket_local_cluster_l2hit_latency)
    for ((n = 0; n < total_sockets; n++)); do
        for ((c = 0, i = 0; c < cores_per_socket; c += cores_per_die, i++)); do
            for ((r = 1; r <= sample_core_count; r++)); do
                IFS= read -r rnd_core < <(get_random_core $c $n $((sd + r)))
                cmd="--idle_latency -b800 -t${DURATION} -c$rnd_core"
                ${MLC_BIN} ${cmd}
            done
        done
    done
    ;;

remote_socket_remotely_homed_l2hitm_latency)
    if [ "${total_sockets}" -lt 2 ]; then
        echo -e "\n****Error: Found single socket. 'remote_socket_remotely_homed_l2hitm_latency' can not be calculated ****\n"
        exit
    fi
    for ((l = 0; l < total_sockets; l++)); do
        for ((r = 0; r < total_sockets; r++)); do
            if [[ $l -eq $r ]]; then
                continue
            fi
            for ((c = 0; c < cores_per_socket; c += cores_per_die)); do
                for ((i = 0; i < cores_per_socket; i += cores_per_die)); do
                    for ((s = 1; s <= sample_core_count; s++)); do
                        IFS= read -r rnd_core1 < <(get_random_core $c $l $((sd + s)))
                        IFS= read -r rnd_core2 < <(get_random_core $i $r $((sd + s)))
                        cmd="--c2c_latency -b1g -C500k -c$rnd_core1 -i$rnd_core2 -w$rnd_core2"
                        ${MLC_BIN} ${cmd}
                    done
                done
            done
        done
    done
    ;;

local_socket_remote_cluster_locally_homed_l2hitm_latency)
    for ((n = 0; n < total_sockets; n++)); do
        for ((c = 0, i = 0; c < cores_per_socket; c += cores_per_die, i++)); do
            for ((w = 0, j = 0; w < cores_per_socket; w += cores_per_die, j++)); do
                if [[ $i -eq $j ]]; then
                    continue
                fi
                for ((r = 1; r <= sample_core_count; r++)); do
                    IFS= read -r rnd_core1 < <(get_random_core $c $n $((sd + r)))
                    IFS= read -r rnd_core2 < <(get_random_core $w $n $((sd + r)))
                    cmd="--c2c_latency -b1g -C500k -c$rnd_core1 -i$rnd_core1 -w$rnd_core2"
                    ${MLC_BIN} ${cmd}
                done
            done
        done
    done
    ;;

local_socket_local_cluster_l3hit_latency)
    for ((n = 0; n < total_sockets; n++)); do
        for ((c = 0, i = 0; c < cores_per_socket; c += cores_per_die, i++)); do
            for ((r = 1; r <= sample_core_count; r++)); do
                IFS= read -r rnd_core < <(get_random_core $c $n $((sd + r)))
                cmd="--idle_latency -b8m -t${DURATION} -c$rnd_core -i$rnd_core"
                ${MLC_BIN} ${cmd}
            done
        done
    done
    ;;

local_socket_remote_cluster_l3hit_latency)
    for ((n = 0; n < total_sockets; n++)); do
        for ((c = 0, k = 0; c < cores_per_socket; c += cores_per_die, k++)); do
            for ((i = 0, j = 0; i < cores_per_socket; i += cores_per_die, j++)); do
                if [[ $k -eq $j ]]; then
                    continue
                fi
                for ((r = 1; r <= sample_core_count; r++)); do
                    IFS= read -r rnd_core1 < <(get_random_core $c $n $((sd + r)))
                    IFS= read -r rnd_core2 < <(get_random_core $i $n $((sd + r)))
                    IFS= read -r rnd_core3 < <(get_random_core $i $n $((sd + r)) "$rnd_core2")
                    cmd="--c2c_latency -b1g -C500k -c$rnd_core1 -i$rnd_core2 -w$rnd_core2 -S$rnd_core3 -H"
                    ${MLC_BIN} ${cmd}
                done
            done
        done
    done
    ;;

remote_socket_remotely_homed_l3hit_latency)
    if [ "${total_sockets}" -lt 2 ]; then
        echo -e "\n****Error: Found single socket. 'remote_socket_remotely_homed_l3hit_latency' can not be calculated ****\n"
        exit
    fi
    for ((l = 0; l < total_sockets; l++)); do
        for ((r = 0; r < total_sockets; r++)); do
            if [[ $l -eq $r ]]; then
                continue
            fi
            for ((c = 0; c < cores_per_socket; c += cores_per_die)); do
                for ((i = 0; i < cores_per_socket; i += cores_per_die)); do
                    for ((s = 1; s <= sample_core_count; s++)); do
                        IFS= read -r rnd_core1 < <(get_random_core $c $l $((sd + s)))
                        IFS= read -r rnd_core2 < <(get_random_core $i $r $((sd + s)))
                        IFS= read -r rnd_core3 < <(get_random_core $i $r $((sd + s)) "$rnd_core2")
                        cmd="--c2c_latency -b1g -C500k -c$rnd_core1 -i$rnd_core2 -w$rnd_core2 -S$rnd_core3 -H"
                        ${MLC_BIN} ${cmd}
                    done
                done
            done
        done
    done
    ;;

idle_latency)
    ${MLC_BIN} --idle_latency
    ;;

peak_injection_bandwidth)
    ${MLC_BIN} --peak_injection_bandwidth
    ;;

latency_matrix)
    ${MLC_BIN} --latency_matrix
    ;;

latency_matrix_random_access)
    ${MLC_BIN} --latency_matrix -r
    ;;

cache_to_cache_transfer_latency)
    ${MLC_BIN} --c2c_latency
    ;;

memory_bandwidth_matrix)
    ${MLC_BIN} --bandwidth_matrix
    ;;

*)
    echo "Unsupported $TEST"
    exit 3
    ;;
esac

status=$?

echo "=== END $(basename "$0")"

[ $status -eq 0 ] || exit 4

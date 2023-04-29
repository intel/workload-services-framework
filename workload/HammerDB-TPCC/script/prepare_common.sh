#!/bin/bash -e

mount -o rw,remount /sys
mount -o rw,remount /proc

### cpu tuning
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    echo "Enable cpu performance with scaling_governor"
    for d in $(ls -d /sys/devices/system/cpu/cpu*|grep 'cpu[0-9]\+')
    do
        (echo performance > $d/cpufreq/scaling_governor) > /dev/null 2>&1 || true
    done
else
    echo "Skip to enable cpu performance due to scaling_governor not found"
fi

if ${ENABLE_TUNING:-true}; then
    echo "Tuning on OS flags"
    set -x
    ### memory tuning
    # disable THP
    trap "echo $(cat /sys/kernel/mm/transparent_hugepage/enabled | awk -F'[][]' '{print $2}') > /sys/kernel/mm/transparent_hugepage/enabled" EXIT
    echo never > /sys/kernel/mm/transparent_hugepage/enabled

    # Add user group to hugetlb_shm_group, enabling hugepage
    echo 999 > /proc/sys/vm/hugetlb_shm_group || true

    # avoid to use swap
    echo 1 > /proc/sys/vm/swappiness
    # always overcommit never check
    echo 1 > /proc/sys/vm/overcommit_memory

    ### network tuning, refer to https://docs.continuent.com/tungsten-clustering-6.1/performance-networking.html
    # Do not cache metrics on closing connections
    echo 1 > /proc/sys/net/ipv4/tcp_no_metrics_save

    # Turn on window scaling which can enlarge the transfer window
    echo 1 > /proc/sys/net/ipv4/tcp_window_scaling

    # Enable timestamps as defined in RFC1323
    echo 1 > /proc/sys/net/ipv4/tcp_timestamps

    # Enable select acknowledgments
    echo 1 > /proc/sys/net/ipv4/tcp_sack

    # Maximum number of remembered connection requests not yet acknowleged by client
    echo 10240 > /proc/sys/net/ipv4/tcp_max_syn_backlog

    # Recommended for hosts with jumbo frames enabled
    echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing

    # Allowed local port range
    echo "1024 65535" > /proc/sys/net/ipv4/ip_local_port_range

    # Protect against TCP time-wait
    echo 1 > /proc/sys/net/ipv4/tcp_rfc1337

    # Decrease the time default value for tcp_fin_timeout connection
    echo 15 > /proc/sys/net/ipv4/tcp_fin_timeout

    # Increase number of incoming connections backlog queue
    echo 65536 > /proc/sys/net/core/netdev_max_backlog

    # Increase the maximum amount of option memory buffers
    echo 25165824 > /proc/sys/net/core/optmem_max

    # Default socket receive buffer
    echo 25165824 > /proc/sys/net/core/rmem_default

    # Default socket send buffer
    echo 25165824 > /proc/sys/net/core/wmem_default

    # Increase the read-buffer space allocatable(min, init, max) bytes
    echo "20480 12582912 25165824" > /proc/sys/net/ipv4/tcp_rmem

    # Increase the read-buffer space allocatable(min, init, max) bytes
    echo "20480 12582912 25165824" > /proc/sys/net/ipv4/tcp_wmem

    # Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks
    echo 1440000 > /proc/sys/net/ipv4/tcp_max_tw_buckets

    # Allow to reuse TIME-WAIT sockets for new connections
    echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
    set +x
fi

# network rps tunning
if ! ${RUN_SINGLE_NODE:-true}; then
    # on multi-node
    if ${ENABLE_RPSRFS_AFFINITY:-true}; then
        echo "Enable rps/rfs"
        source /network_rps_tuning.sh # enable network RPS tunning on multi-node
    fi
fi

#!/bin/bash -e

B_PER_KB=1024
KB_PER_MB=1024
MB_PER_GB=1024
KB_PER_GB=`expr $KB_PER_MB \* $MB_PER_GB`

num_numa_nodes=`lscpu | grep "NUMA node(s)" | awk '{print $3}'`
num_cores=`lscpu | grep "CPU(s):      " | awk '{print $2}' | head -n 1`
num_cores_per_numanode=`expr $num_cores / $num_numa_nodes`
m_mongodb_record_count=$m_record_count

if [[ "${m_mongo_disk_database_access}" = true ]]
then
    echo "reduce amount of memory available to mongodb and file cache"
    memory_available=`cat /proc/meminfo | grep MemAvailable | awk '{print $2}'`
    min_size=`expr 1 \* $KB_PER_GB`
    calc_size=`echo "(($m_mongodb_record_count * $m_field_count * $m_field_length) / $B_PER_KB) * $m_mongodb_percentage_db_cache_db" | bc`
    if [ `echo "$calc_size > $min_size" | bc` -ne 0 ];then
        cache_size_kb=$calc_size
    else
        cache_size_kb=$min_size
    fi
    process_kb=$min_size
    bookkeeping_per_record_b=256
    bookkeeping_b=`expr $m_mongodb_record_count \* $bookkeeping_per_record_b`
    bookkeeping_kb=`expr $bookkeeping_b / $B_PER_KB`
    fs_cache_kb=$cache_size_kb
    memory_required_per_instance_kb=`expr $cache_size_kb + $process_kb + $bookkeeping_kb + $fs_cache_kb`
    mongodb_reserve_kb=`expr $memory_required_per_instance_kb \* $m_client_server_pair`
    os_overhead_kb=`expr $MB_PER_GB \* $KB_PER_MB`  # reserve 1GB for OS
    fill_kb=`expr $memory_available - $mongodb_reserve_kb - $os_overhead_kb`
    fill_kb_per_numanode=`expr $fill_kb / $num_numa_nodes`
    if [ $num_numa_nodes -gt 1 ]; then
        for((i=0;i<$num_numa_nodes;i++));
        do
            numactl --cpunodebind=$i --membind=$i -- stress-ng --vm-bytes ${fill_kb}k --vm-keep --vm-hang 0 --vm ${num_cores_per_numanode} &
        done
    else 
        stress-ng --vm-bytes ${fill_kb}k --vm-keep --vm-hang 0 --vm ${num_cores_per_numanode} &
    fi
fi
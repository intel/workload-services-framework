#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
INSTRUCTION_SET=${INSTRUCTION_SET:-sve}
NTIMES=${NTIMES:-500}

echo "The instruction set is $INSTRUCTION_SET."
echo "The platform is $PLATFORM."
echo "The number of iterations of each kernel is $NTIMES."

Threads=$(lscpu | grep "CPU(s): " -m 1 | awk '{print $2}')
ThreadsperCore=$(lscpu | grep "Thread(s) per core:" | awk '{print $4}')
Cores=$Threads

echo "Cores= $Cores"

Threads=$(lscpu | grep "CPU(s): " -m 1 | awk '{print $2}')
ThreadsperCore=$(lscpu | grep "Thread(s) per core:" | awk '{print $4}')
Cores=$(("$Threads" / "$ThreadsperCore" ))
sync; echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory

NUMSOCK=${1:-`grep 'physical id' /proc/cpuinfo | sort -u | wc -l`}
echo $NUMSOCK sockets

# get id of each socket
socketidlist=`grep "physical id" /proc/cpuinfo | sort -u | awk '{(es=="")?es=$4:es=es" "$4} END{print es}'`
echo "    IDs of Sockets:" $socketidlist

# get number of logical cores
NUMPROC=${1:-`grep -c 'processor' /proc/cpuinfo`}
echo "   " $NUMPROC logical cores in total

if [[ $CLOUDFLAG == "true" ]]; then
  Cores=$Threads
fi

total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
if [ "$total_sockets" = "-" ]; then
  total_sockets=1
fi

cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
cores_per_socket=${cores_per_socket:-1}
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
l2_cache_mb=$(lscpu | grep "L2 cache" | awk '{print $3}')
l3_cache_mb=$(lscpu | grep "L3 cache" | awk '{print $3}')
l2_cache_size=$((l2_cache_mb*1024*1024))
l3_cache_size=$((l3_cache_mb*1024*1024))
total_cache_size=$((l3_cache_size + l2_cache_size))
echo "Total Cache Size: $total_cache_size"
size_bytes=$(echo "${total_cache_size} * 4" | bc | cut -f1 -d ".")
echo "Size in bytes : $size_bytes"

if [ "$size_bytes" = "0" ]; then
  echo "Probably running in an emulator. Use the default"
  size_bytes=10000000
fi
echo "size_byte ${size_bytes}"
(( stream_array_size = size_bytes / 8 ))
echo "stream_array_size: $stream_array_size"

required_mem_size=$(echo "${size_bytes}  * 3 / 1024" | bc | cut -f1 -d ".")
mem_free=$(awk '/MemFree:/{print $2}' /proc/meminfo)

echo "req_size(kb): ${required_mem_size}"
echo "mem_free(kb): ${mem_free}"

#-------------------------Memory in VM may be insufficient for this array_size------------------------
if [[ $required_mem_size > $mem_free ]]; then
    echo "Memory is insufficient for this array_size, recalculate the size..."
    size_bytes=$(echo "${mem_free} * 1024 / 10 / 3" | bc |  cut -f1 -d ".")
    echo "recalculate_arr_size: $size_bytes"
fi

# Run the free command and store the output in a variable
memory_info=$(free -h | grep "Mem:")

# Print the free memory information
echo "Free Memory Information after cahce clean and memory compaction:"
echo "$memory_info"

echo "Cores= $Cores"


echo "build stream with gcc compiler (Arm)"
gcc-12 -mtune=native -march=native -O3 -fno-pic -ffp-contract=fast -mcmodel=large -fopenmp -DSTREAM_ARRAY_SIZE=$stream_array_size -DNTIMES=$NTIMES stream.c -o stream-gcc
BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]; then
   echo "Problem building Stream GCC armv9"
   exit $BUILD_RESULT
fi
gcc-12 -mtune=native -march=native -O3 -fno-pic -ffp-contract=fast -mcmodel=large -fopenmp -DSTREAM_ARRAY_SIZE=$stream_array_size -DNTIMES=$NTIMES stream.c -o sve_STREAM_268435456
BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]; then
   echo "Problem building Stream GCC armv9"
   exit $BUILD_RESULT
fi
gcc-12 -mtune=native -march=native -O3 -fno-pic -ffp-contract=fast -mcmodel=large -fopenmp -DSTREAM_ARRAY_SIZE=$stream_array_size -DNTIMES=$NTIMES stream.c -o sve2_STREAM_268435456
BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]; then
   echo "Problem building Stream GCC armv9"
   exit $BUILD_RESULT
fi



export OMP_PROC_BIND=close

#OMP_NUM_THREADS is set to core count, not thread count. Ex: 2-Socket 40C will be 80 Cores.
export OMP_NUM_THREADS=$Cores

# default asimd binary
stream=$streamgcc

case "$INSTRUCTION_SET" in
sve)
    echo "The number of iterations of each kernel is 500."
    stream=sve_STREAM_268435456
    ;;

sve2)
    echo "The number of iterations of each kernel is 500."
    stream=sve2_STREAM_268435456
    ;;

*)
    # default avx512 binary, avx3 is also avx512 equivalent for SPR
    stream=stream-gcc
    ;;
esac

echo "run stream"
./$stream
exit_code=$?

# Check if command executed successfully
if [ $exit_code -ne 0 ]; then
    echo "------ Execution of $stream failed ------"
    exit 3
fi

echo "------ Execution of $stream completed successfully ------"

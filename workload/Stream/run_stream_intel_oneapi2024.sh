#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

INSTRUCTION_SET=${INSTRUCTION_SET:-sse}
NTIMES=${NTIMES:-500}
ENABLE_PRIVILEGED_MODE=${ENABLE_PRIVILEGED_MODE:-false}
NO_OF_STREAM_ITERATIONS=${NO_OF_STREAM_ITERATIONS:-1}
STREAM_ARRAY_SIZE=${STREAM_ARRAY_SIZE:-}

echo "The instruction set is $INSTRUCTION_SET."
echo "The platform is $PLATFORM."
echo "The number of iterations of each kernel is $NTIMES."

INTEL_ONEAPI=/opt/intel/oneapi

# shellcheck source=/dev/null
source ${INTEL_ONEAPI}/setvars.sh
source info.sh

Threads=$(lscpu | grep "CPU(s): " -m 1 | awk '{print $2}')
ThreadsperCore=$(lscpu | grep "Thread(s) per core:" | awk '{print $4}')
Cores=$(("$Threads" / "$ThreadsperCore" ))
sync; echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory

if [[ $CLOUDFLAG == "true" ]]; then
  Cores=$Threads
fi

total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
if [ "$total_sockets" = "-" ]; then
  total_sockets=1
fi

#------------------------------  SYSTEM PARAMS -----------------------------------
total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
if [ "$total_sockets" = "-" ]; then
  total_sockets=1
fi

cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
cores_per_socket=${cores_per_socket:-1}
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
l3_cache_mb=$(lscpu | grep "L3 cache" | awk '{print $3}')
echo "L3 Cache per socket: ${l3_cache_mb} MB"

total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
echo "Total Sockets: ${total_sockets}"

total_cache_size=$(echo "${l3_cache_mb} * ${total_sockets}" | bc)
size_bytes=$(echo "${total_cache_size} * 4 * 1000 * 1000" | bc)
echo "Total Cache Size in Bytes: $size_bytes"

if [ "$size_bytes" -eq 0 ]; then
  echo "Running in an emulator. Using default size_bytes=10000000."
  size_bytes=10000000
fi

STREAM_ARRAY_SIZE=$(echo "(${size_bytes} * 1.4) / 8" | bc)
echo "STREAM_ARRAY_SIZE: $STREAM_ARRAY_SIZE"

if (( required_mem_size > mem_free )); then
    echo "Memory is insufficient. Recalculating..."
    size_bytes=$(echo "${mem_free} * 1024 / 10 / 3" | bc)
    echo "Recalculated size_bytes: $size_bytes"
fi

# Run the free command and store the output in a variable
memory_info=$(free -h | grep "Mem:")

# Print the free memory information
echo "Free Memory Information after cahce clean and memory compaction:"
echo "$memory_info"

echo "Cores= $Cores"

#KMP_AFFINITY

if [ "$threads_per_core" -eq 2 ]; then
    export KMP_AFFINITY="granularity=fine,compact,1,0"
else
    export KMP_AFFINITY="compact"
fi

echo "KMP_AFFINITY set to: $KMP_AFFINITY"

#OMP_NUM_THREADS is set to core count, not thread count. Ex: 2-Socket 40C will be 80 Cores.
export OMP_NUM_THREADS=$NUMPROC

# Intel AVX-512
echo "=============================================================================Build Knob for Stream with icx 2024 Compiler for AVX512====================================================================================================================="
echo "icx -Wall -O3 -mcmodel=medium -qopenmp -fno-builtin -qopt-streaming-stores=always -xCORE-AVX512 -qopt-zmm-usage=high -DNTIMES=$NTIMES -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE  stream.c -o avx512_STREAM"
echo "=========================================================================================================================================================================================================================================================="
icx -Wall -O3 -mcmodel=medium -qopenmp -fno-builtin -qopt-streaming-stores=always -xCORE-AVX512 -qopt-zmm-usage=high -DNTIMES=$NTIMES -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE stream.c -o avx512_STREAM

BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]
then
   echo "Problem building AVX-512 Stream"
   exit $BUILD_RESULT
fi

# Intel AVX2
echo "=============================================================================Build Knob for Stream with icx 2024 Compiler for AVX2====================================================================================================================="
echo "icx -Wall -O3 -mcmodel=medium -qopenmp -fno-builtin -qopt-streaming-stores=always -xCORE-AVX2 -DNTIMES=$NTIMES -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE  stream.c -o avx2_STREAM"
echo "========================================================================================================================================================================================================================================================"
icx -Wall -O3 -mcmodel=medium -qopenmp -fno-builtin -qopt-streaming-stores=always -xCORE-AVX2 -DNTIMES=$NTIMES -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE  stream.c -o avx2_STREAM

BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]
then
   echo "Problem building AVX2 Stream"
   exit $BUILD_RESULT
fi

# Intel SSE
echo "=============================================================================Build Knob for Stream with icx 2024 Compiler for SSE ====================================================================================================================="

echo "icx -O3 -msse4.2 -mcmodel=medium -ffreestanding -qopenmp -qopenmp-link=static -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE -DNTIMES=$NTIMES stream.c -o sse_STREAM"
icx -O3 -msse4.2 -mcmodel=medium -ffreestanding -qopenmp -qopt-streaming-stores=always  -qopenmp-link=static -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE -DNTIMES=$NTIMES stream.c -o sse_STREAM

BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]
then
   echo "Problem building SSE Stream"
   exit $BUILD_RESULT
fi

# Intel AVX
echo "=============================================================================Build Knob for Stream with icx 2024 Compiler for AVX====================================================================================================================="
echo "icx -Wall -O3 -mcmodel=medium -qopenmp -fno-builtin -qopt-streaming-stores=always -xAVX -DNTIMES=$NTIMES -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE  stream.c -o avx_STREAM"
echo "========================================================================================================================================================================================================================================================"
icx -Wall -O3 -mcmodel=medium -qopenmp -fno-builtin -qopt-streaming-stores=always -xAVX -DNTIMES=$NTIMES -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE  stream.c -o avx_STREAM
BUILD_RESULT=$?
if [[ $BUILD_RESULT != 0 ]]
then
   echo "Problem building AVX Stream"
   exit $BUILD_RESULT
fi




case "$INSTRUCTION_SET" in
avx2)
    stream=avx2_STREAM
    ;;
sse4.2)
    stream=sse_STREAM
    ;;
sse)
    stream=sse_STREAM
    ;;
avx)
    stream=avx_STREAM
    ;;
*)
    # default avx512 binary, avx3 is also avx512 equivalent
    stream=avx512_STREAM
    ;;
esac


NO_OF_STREAM_ITERATIONS="$NO_OF_STREAM_ITERATIONS"

 # Number of times to run the loop
i=1     # Initialize counter

if ! [[ "$NO_OF_STREAM_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Error: NO_OF_STREAM_ITERATIONS is not set or not a numeric value"
    exit 1
fi

while [ $i -le $NO_OF_STREAM_ITERATIONS ]; do
    echo "run stream"
    echo "start benchmark"
    echo "running $stream"
    sleep 17
    start_time=$(date +%s)

    # Execute based on ENABLE_PRIVILEGED_MODE
    if [ "${ENABLE_PRIVILEGED_MODE}" == "true" ]; then
        numactl --physcpubind="${cpuset[NUMSOCK]}" -l "./$stream"
        exit_code=$?
        echo "Run_cmd: numactl --physcpubind=${cpuset[NUMSOCK]} -l ./$stream"
    else
        "./$stream"
        exit_code=$?
        echo "Run_cmd: ./$stream"
    fi

    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    echo "Elapsed time: $elapsed_time seconds"

    # Check if command executed successfully
    if [ $exit_code -ne 0 ]; then
        echo "------ Test failed on iteration $i ------"
        exit 3
    fi

    echo "====== Iteration: $i completed successfully ======"
    echo "==== NO_OF_STREAM_ITERATIONS: $NO_OF_STREAM_ITERATIONS ===="
    echo "==== ENABLE_PRIVILEGED_MODE: $ENABLE_PRIVILEGED_MODE ===="

    i=$((i + 1))  # Increment counter
done

echo "------ All tests completed successfully! ------"
exit 0
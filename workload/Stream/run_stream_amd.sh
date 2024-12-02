#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

INSTRUCTION_SET=${INSTRUCTION_SET:-sse}
NTIMES=${NTIMES:-500}

echo "The number of iterations of each kernel is $NTIMES."
echo "The instruction set is $INSTRUCTION_SET."
echo "The platform is $PLATFORM."

AOCC_DIR=/opt/AMD

# shellcheck source=/dev/null
source ${AOCC_DIR}/setenv_AOCC.sh


Threads=$(lscpu | grep "CPU(s): " -m 1 | awk '{print $2}')
ThreadsperCore=$(lscpu | grep "Thread(s) per core:" | awk '{print $4}')
Cores=$(("$Threads" / "$ThreadsperCore" ))
if [[ $CLOUDFLAG == "true" ]]; then
  Cores=$Threads
fi
echo "Cores= $Cores"

sync; echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory

#------------------------------  SYSTEM PARAMS -----------------------------------
total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
total_sockets=${total_sockets:-1}

cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
cores_per_socket=${cores_per_socket:-1}

threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')

l2_cache_mb=$(lscpu | grep "L2 cache" | awk '{print $3}')
l3_cache_mb=$(lscpu | grep "L3 cache" | awk '{print $3}')
l2_cache_size=$((l2_cache_mb*1024*1024))
l3_cache_size=$((l3_cache_mb*1024*1024))
total_cache_size=$((l3_cache_size + l2_cache_size))
echo "Total Cache Size: $total_cache_size"
echo "l2_cache_mb: $l2_cache_mb"
echo "l3_cache_mb: $l3_cache_mb"
size_bytes=$(echo "${total_cache_size} * 4" | bc | cut -f1 -d ".")

if [[ "$size_bytes" -eq 0 ]]; then
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
if [[ $required_mem_size -gt $mem_free ]]; then
    echo "Memory is insufficient for this array_size, recalculate the size..."
    size_bytes=$(echo "${mem_free} * 1024 / 10 / 3" | bc |  cut -f1 -d ".")
    echo "recalculate_arr_size: $size_bytes"
fi

# Run the free command and store the output in a variable
memory_info=$(free -h | grep "Mem:")

# Print the free memory information
echo "Free Memory Information after cahce clean and memory compaction:"
echo "$memory_info"

#----------------------------------------------build stream with aocc compilers-----------------------------------------------
# Function to build the stream
echo "build stream with aocc compiler (AMD)"
build_stream() {
  local instruction_set=$1
  local output_file=$2
  clang stream.c -O3 -mcmodel=large -DSTREAM_TYPE=double -${instruction_set} -DSTREAM_ARRAY_SIZE=$stream_array_size -DNTIMES=$NTIMES -ffp-contract=fast -fnt-store -fopenmp -o "$output_file"
  local build_result=$?
  if [[ $build_result != 0 ]]; then
    echo "Problem building AOCC $instruction_set Stream"
    exit $build_result
  fi
}

# Build streams
build_stream "msse4.2" "sse_STREAM"
build_stream "mavx" "avx_STREAM"
build_stream "mavx2" "avx2_STREAM"
build_stream "mavx512f" "avx3_STREAM"

#KMP_AFFINITY
export KMP_AFFINITY=scatter

#OMP_NUM_THREADS is set to core count, not thread count. Ex: 2-Socket 40C will be 80 Cores.
export OMP_NUM_THREADS=$Cores

# default
stream=sse_STREAM

case "$INSTRUCTION_SET" in
sse)
  stream=sse_STREAM
  ;;
avx2)
  stream=avx2_STREAM
  ;;
avx3)
  stream=avx3_STREAM
  ;;
avx)
  echo "The number of iterations of each kernel is 100."
  stream=avx_STREAM
  ;;
*)
  echo -e "\nNote: Running the Default with SSE\n"
  exit 1
  ;;
esac

echo "run stream"
./$stream

#!/bin/bash

INSTRUCTION_SET=${INSTRUCTION_SET:-sse}
NTIMES=${NTIMES:-100}
WORKLOAD=${WORKLOAD:-stream}

echo "The instruction set is $INSTRUCTION_SET."
echo "The platform is $PLATFORM."
echo "The number of iterations of each kernel is $NTIMES."

case "$INSTRUCTION_SET" in
sse)

    arch="SSE4.2"
    ;;
avx2)
    arch="core-avx2"
    ;;
avx3)
    arch="COMMON-AVX512"
    ;;
*)
    echo -e "\nError: Unknown Instruction Set ${INSTRUCTION_SET}. Valid arguments are: sse, avx2, avx3\n"
    exit 1
    ;;
esac

#------------------------------  SYSTEM PARAMS -----------------------------------
total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
if [ "$total_sockets" = "-" ]; then 
  total_sockets=1 
fi

cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
cores_per_socket=${cores_per_socket:-1}
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
total_cores=$((cores_per_socket*total_sockets*threads_per_core))
l3_cache_size=$(getconf LEVEL3_CACHE_SIZE)
array_size=$(echo "${l3_cache_size} * ${total_sockets} * 3.8" | bc | cut -f1 -d ".")

if [ "$array_size" = "0" ]; then
  echo "Probably running in an emulator. Use the default"
  array_size=10000000
fi
echo "arr_size ${array_size}"

required_mem_size=$(echo "${array_size} * 8 * 3 / 1024" | bc | cut -f1 -d ".")
mem_free=$(awk '/MemFree:/{print $2}' /proc/meminfo)

echo "req_size(kb): ${required_mem_size}"
echo "mem_free(kb): ${mem_free}"

#-------------------------Memory in VM may be insufficient for this array_size------------------------
if [[ $required_mem_size > $mem_free ]]; then
    echo "Memory is insufficient for this array_size, recalculate the size..."
    array_size=$(echo "${mem_free} * 1024 / 10 / 3" | bc |  cut -f1 -d ".")
    echo "recalculate_arr_size: $array_size"
fi

#------------------------ stream workload setup and run---------------------------------------------
export OMP_NUM_THREADS=${total_cores}
export KMP_AFFINITY=compact,1

if [[ $WORKLOAD == "stream" ]];then
  echo "build stream with Intel icx compiler"

  source /opt/intel/oneapi/setvars.sh --force intel64
  icx -O3 -x${arch} -qopenmp -mcmodel=medium -DSTREAM_ARRAY_SIZE="${array_size}" -DNTIMES="${NTIMES}" stream.c -o stream -ffreestanding
fi

echo "run stream"
./stream

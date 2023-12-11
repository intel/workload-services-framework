#!/bin/bash

INSTRUCTION_SET=${INSTRUCTION_SET:-sse}
NTIMES=${NTIMES:-100}

echo "The instruction set is $INSTRUCTION_SET."
echo "The platform is $PLATFORM."

Threads=$(lscpu | grep "CPU(s): " -m 1 | awk '{print $2}')
ThreadsperCore=$(lscpu | grep "Thread(s) per core:" | awk '{print $4}')
Cores=$(("$Threads" / "$ThreadsperCore" ))

if [[ $CLOUDFLAG == "true" ]]; then
  Cores=$Threads
fi

echo "Cores= $Cores"

#KMP_AFFINITY
export KMP_AFFINITY=scatter

#OMP_NUM_THREADS is set to core count, not thread count. Ex: 2-Socket 40C will be 80 Cores.
export OMP_NUM_THREADS=$Cores

case "$INSTRUCTION_SET" in
avx2)
    echo "The number of iterations of each kernel is 100."
    stream=avx2_STREAM_268435456
    ;;
sse4.2)
    echo "The number of iterations of each kernel is 220."
    stream=stream_omp_NTW
    ;;
avx512)
    echo "The number of iterations of each kernel is 500."
    stream=icpc_avx512_STREAM_268434456
    ;;
avx)
    echo "The number of iterations of each kernel is 100."
    stream=avx_STREAM_268435456
    ;;
*)
    # default avx512 binary, avx3 is also avx512 equivalent for SPR
    stream=avx512_STREAM_268435456
    ;;
esac

echo "run stream"
./$stream

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -e "/opt/intel/oneapi/setvars.sh" ]; then
    source /opt/intel/oneapi/setvars.sh
fi

print_title() {
    echo -e "##############################"
    echo -e $1
    echo -e "##############################"
}

print_subtitle() {
    echo -e "***" $1 "***"
}

print_end() {
    echo -e "\n"
}

start_check() {
    print_title "Precondition Check"

    precondition_check_result="passed"
}

check_memory() {
    print_subtitle "Checking memory resources"
    local ret=0
    memory_needs=$1
    echo -e "memory needs(G): " $memory_needs
    memory_free=$(free -g | awk '/Mem:/{print $7}')
    echo -e "current available memory(G): " $memory_free
    if [ $memory_free -lt $memory_needs ]; then
        echo -e "\t[FAILED]"
        precondition_check_result="failed"
    else
        echo -e "\t[PASSED]"
    fi
}

print_check_result() {
    if [ $precondition_check_result == "passed" ]; then
        echo -e "--Precondition check result: PASSED"
        print_end
    else 
        echo -e "--Precondition check result: FAILED. Your case may fail due to memory limit."
        print_end
    fi
}

# Get hardware info
sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
numa_nodes=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')

cores_without_ht=$(($cores_per_socket * $sockets))
cores_per_numa=$(($cores_without_ht / $numa_nodes))
cores_with_ht=$(($cores_without_ht * $threads_per_core))

CONFIG=${CONFIG:-avx512}
X_DIMENSION=${X_DIMENSION:-192}
Y_DIMENSION=${Y_DIMENSION:-192}
Z_DIMENSION=${Z_DIMENSION:-192}
RUN_SECONDS=${RUN_SECONDS:-60}

PROCESS_PER_NODE=${PROCESS_PER_NODE:-socket}
if [ $PROCESS_PER_NODE == "socket" ]; then
    PROCESS_PER_NODE=$sockets
elif [ $PROCESS_PER_NODE == "numa" ]; then
    PROCESS_PER_NODE=$numa_nodes
fi

OMP_NUM_THREADS=${OMP_NUM_THREADS:-socket}
if [ $OMP_NUM_THREADS == "socket" ]; then
    OMP_NUM_THREADS=${cores_per_socket}
elif [ $OMP_NUM_THREADS == "numa" ]; then
    OMP_NUM_THREADS=${cores_per_numa}
fi

total_threads=$(($PROCESS_PER_NODE * $OMP_NUM_THREADS))
if [ $total_threads -gt $cores_without_ht ]; then
    if [ $threads_per_core == 1 ]; then
    # using one thread per core
        echo "Case setting is not reasonable: $PROCESS_PER_NODE * $OMP_NUM_THREADS(total threads) is greater than $cores_without_ht(total cores). "
        exit 111
    elif [ $threads_per_core == 2 ]; then
    # hyperthreading enabled
        if [ $total_threads -gt $cores_with_ht ]; then
            echo "Case setting is not reasonable: $PROCESS_PER_NODE * $OMP_NUM_THREADS(total threads) is greater than $cores_with_ht(total cores). "
            exit 111
        fi
    fi
fi

if [ "$CONFIG" = "amd-avx512" ] || [ "$CONFIG" = "amd-avx2" ]; then
    if [ "$THREADS_PER_SOCKET" != "" ]; then
        if [ $THREADS_PER_SOCKET -gt $cores_per_socket ]; then
            echo "THREADS_PER_SOCKET $THREADS_PER_SOCKET is larger than $cores_per_socket, it's not allowed. Exiting"
            exit 1
        else
            PROCESS_PER_NODE=$THREADS_PER_SOCKET
        fi
    else
        PROCESS_PER_NODE=$cores_per_socket
    fi
fi

# In theory, only effect on Intel MKL
KMP_AFFINITY=${KMP_AFFINITY:-compact0}
if [ $KMP_AFFINITY == "compact1" ]; then
    KMP_AFFINITY=compact,1
elif [ $KMP_AFFINITY == "compact0" ]; then
    KMP_AFFINITY=compact
elif [ $KMP_AFFINITY == "scatter0" ]; then
    KMP_AFFINITY=scatter
elif [ $KMP_AFFINITY == "threadcompact1" ]; then
    KMP_AFFINITY=granularity=fine,compact,1
elif [ $KMP_AFFINITY == "threadcompact0" ]; then
    KMP_AFFINITY=granularity=fine,compact
elif [ $KMP_AFFINITY == "threadscatter0" ]; then
    KMP_AFFINITY=granularity=fine,scatter
else
    KMP_AFFINITY=compact,1
fi
if [ "$CONFIG" = "amd-avx512" ] || [ "$CONFIG" = "amd-avx2" ]; then
    KMP_AFFINITY=
fi

# mpi param for mapping processes
if [ $OMP_NUM_THREADS -le $cores_per_numa ]; then
    MPI_AFFINITY=${MPI_AFFINITY:-numa}
else 
    MPI_AFFINITY=${MPI_AFFINITY:-socket}
fi
if [ $MPI_AFFINITY == "numa" ]; then
    MAP_BY_PARAM=ppr:$((${PROCESS_PER_NODE} / ${numa_nodes})):numa:PE:$OMP_NUM_THREADS
elif [ $MPI_AFFINITY == "socket" ]; then
    MAP_BY_PARAM=ppr:$(($((${PROCESS_PER_NODE} / ${sockets})))):socket:PE:$OMP_NUM_THREADS
elif [ $MPI_AFFINITY == "l3cache" ]; then
    MAP_BY_PARAM=L3cache
else
    MAP_BY_PARAM=socket
fi
if [ "$CONFIG" = "amd-avx512" ] || [ "$CONFIG" = "amd-avx2" ]; then
    MAP_BY_PARAM=l3cache:PE=2
fi
if [ "$CONFIG" = "amd-avx512" ] || [ "$CONFIG" = "amd-avx2" ]; then
    cd /hpcg
else
    cd /hpcg/bin
fi
export OMP_NUM_THREADS KMP_AFFINITY
if [ "${CONFIG}" == "generic" ]; then
    XHPCG_PATH=xhpcg
elif [ "${CONFIG}" == "avx" ]; then
    XHPCG_PATH=xhpcg_avx
elif [ "${CONFIG}" == "avx2" ]; then
    XHPCG_PATH=xhpcg_avx2
elif [ "${CONFIG}" == "avx512" ]; then
    XHPCG_PATH=xhpcg_skx
elif [ "${CONFIG}" == "amd-avx512" ]; then
    XHPCG_PATH=amd_hpcg_avx512
elif [ "${CONFIG}" == "amd-avx2" ]; then
    XHPCG_PATH=amd_hpcg_avx2
else
    XHPCG_PATH=xhpcg
fi

echo "$XHPCG_PATH run with parameters: $X_DIMENSION*$Y_DIMENSION*$Z_DIMENSION in $RUN_SECONDS seconds. $PROCESS_PER_NODE * $OMP_NUM_THREADS:$total_threads $KMP_AFFINITY $MPI_AFFINITY"

# interesting to see intel version is using -t
#mpirun -np $NP_PARAM ./$XHPCG_PATH --nx=$X_DIMENSION --ny=$Y_DIMENSION --nz=$Z_DIMENSION -t=$RUN_SECONDS
# interesting to see generic version is using --rt
#mpirun -np $NP_PARAM ./$XHPCG_PATH --nx=$X_DIMENSION --ny=$Y_DIMENSION --nz=$Z_DIMENSION --rt=$RUN_SECONDS
# both seems support numbers only
if [ "$CONFIG" = "amd-avx512" ] || [ "$CONFIG" = "amd-avx2" ]; then
    echo "command: mpirun --allow-run-as-root -np ${PROCESS_PER_NODE} --bind-to core:overload-allowed --map-by ${MAP_BY_PARAM} -x OMP_NUM_THREADS=2 -x OMP_PROC_BIND=true -x OMP_PLACES=cores ./$XHPCG_PATH --nx=$X_DIMENSION --ny=$Y_DIMENSION --nz=$Z_DIMENSION --rt=$RUN_SECONDS"
    # export OMPI_ALLOW_RUN_AS_ROOT=1
    # export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
    start_check
    memory_needs=`expr $PROCESS_PER_NODE \* 13`
    check_memory $memory_needs

    print_check_result

    mpirun --allow-run-as-root -np ${PROCESS_PER_NODE} --bind-to core:overload-allowed --map-by ${MAP_BY_PARAM} -x OMP_NUM_THREADS=2 -x OMP_PROC_BIND=true -x OMP_PLACES=cores ./$XHPCG_PATH --nx=$X_DIMENSION --ny=$Y_DIMENSION --nz=$Z_DIMENSION --rt=$RUN_SECONDS
else
    mpirun -np ${PROCESS_PER_NODE} --map-by ${MAP_BY_PARAM} ./$XHPCG_PATH $X_DIMENSION $Y_DIMENSION $Z_DIMENSION $RUN_SECONDS
fi

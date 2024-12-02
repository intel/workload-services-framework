#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
N_SIZE=${N_SIZE:-auto}
P_SIZE=${P_SIZE:-auto}
Q_SIZE=${Q_SIZE:-auto}
NB_SIZE=${NB_SIZE:-auto}
ISA=${ISA:-avx2}
MPI_PROC_NUM=${MPI_PROC_NUM:-auto}
MPI_PER_NODE=${MPI_PER_NODE:-auto}
NUMA_PER_MPI=${NUMA_PER_MPI:-auto}

Sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
Numas=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')
if [[ $Numas -lt $Sockets ]]; then
    Numas=$Sockets
fi

cd /opt/intel/oneapi/mkl/latest/benchmarks/mp_linpack
source /opt/intel/oneapi/setvars.sh

if [ $N_SIZE == "auto" ]; then
    mem=$(free -b | awk '/Mem:/{print $2}')
    N_SIZE=$(echo "sqrt(0.9 * $mem / 32)" | bc)
fi

if [[ $P_SIZE == "auto" ]]; then
    P_SIZE=$Numas
fi

if [[ $Q_SIZE == "auto" ]]; then
    Q_SIZE=1
fi

if [[ $NB_SIZE == "auto" ]]; then
    if [[ $ISA == "avx2" ]]; then
        NB_SIZE=192
    elif [[ $ISA == "sse2" ]]; then
        NB_SIZE=240
    else
        NB_SIZE=384
    fi
fi

if [[ $MPI_PROC_NUM == "auto" ]]; then
    MPI_PROC_NUM=$(( $P_SIZE * $Q_SIZE ))
fi

if [[ $MPI_PER_NODE == "auto" ]]; then
    MPI_PER_NODE=$MPI_PROC_NUM
fi

if [[ $NUMA_PER_MPI == "auto" ]]; then
    NUMA_PER_MPI=1
fi

if [[ $ISA == "avx2" ]]; then
    export MKL_ENABLE_INSTRUCTIONS=AVX2
elif [[ $ISA == "sse2" ]]; then
    export MKL_ENABLE_INSTRUCTIONS=SSE4_2
else
    export MKL_ENABLE_INSTRUCTIONS=AVX512
fi

sed -i "s/.*export MPI_PROC_NUM=.*$/export MPI_PROC_NUM=${MPI_PROC_NUM}/" runme_intel64_dynamic
sed -i "s/.*export MPI_PER_NODE=.*$/export MPI_PER_NODE=${MPI_PER_NODE}/" runme_intel64_dynamic
sed -i "s/.*export NUMA_PER_MPI=.*$/export NUMA_PER_MPI=${NUMA_PER_MPI}/" runme_intel64_dynamic
echo "N_SIZE is $N_SIZE, NB_SIZE is $NB_SIZE, P_SIZE is $P_SIZE, Q_SIZE is $Q_SIZE, MPI_PROC_NUM is $MPI_PROC_NUM, MPI_PER_NODE is $MPI_PER_NODE, NUMA_PER_MPI is $NUMA_PER_MPI"
./runme_intel64_dynamic -p $P_SIZE -q $Q_SIZE -b $NB_SIZE -n $N_SIZE

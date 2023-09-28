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
ASM=${ASM:-default_instruction}

Sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
Numas=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')
if [[ $Numas -lt $Sockets ]]; then
    Numas=$Sockets
fi

cd /opt/intel/mkl/benchmarks/mp_linpack
source /opt/intel/oneapi/setvars.sh

if [ $N_SIZE == "auto" ]; then
    mem=$(free -b | awk '/Mem:/{print $2}')
    N_SIZE=$(echo "sqrt(0.9 * $mem / 8)" | bc)
fi

if [[ $P_SIZE == "auto" ]]; then
    P_SIZE=$Sockets
fi

if [[ $Q_SIZE == "auto" ]]; then
    Q_SIZE=$(( $Numas / $Sockets ))
fi

if [[ $NB_SIZE == "auto" ]]; then
    if [[ $ASM == "avx2" ]]; then
        NB_SIZE=192
    elif [[ $ASM == "sse" ]]; then
        NB_SIZE=256
    else
        NB_SIZE=384
    fi
fi

sed -i 's|MPI_PROC_NUM=2|MPI_PROC_NUM='"$Numas"'|g' runme_intel64_dynamic

echo "Using this problem size $N_SIZE"
./runme_intel64_dynamic -p $P_SIZE -q $Q_SIZE -b $NB_SIZE -n $N_SIZE
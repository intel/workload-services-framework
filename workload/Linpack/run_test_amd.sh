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
MAP_BY=${MAP_BY:-socket}

AMDCPU=`lscpu | grep "Model name:" | awk '{print $3,$4,$5,$6,$7}' | tr ' ' '_'`
Sockets=`lscpu | grep "Socket(s):" | awk '{print $2}'`
Numas=`lscpu | grep "NUMA node(s):" | awk '{print $3}'`
if [[ $Numas -lt $Sockets ]]; then
    Numas=$Sockets
fi
Threads=`lscpu | grep "CPU(s):     " -m 1 | awk '{print $2}'`
Threads_Per_Core=`lscpu | grep "Thread(s) per core:" | awk '{print $4}'`
Cores=$(( $Threads / $Threads_Per_Core ))
Cores_Per_Socket=$(( $Cores / $Sockets ))
Cores_Per_Numa=$(( $Cores / $Numas ))

cd /amd-zen-hpl-2023_07_18_automated_v2

if [[ $ISA == "avx2" ]]; then
    export BLIS_ARCH_TYPE=zen4
    export BLIS_ARCH_DEBUG=1
else 
    export BLIS_ARCH_TYPE=zen3
    export BLIS_ARCH_DEBUG=1
fi
export KMP_AFFINITY=
unset OMPI_MCA_osc

if [ $N_SIZE == "auto" ]; then
    mem=$(free -b | awk '/Mem:/{print $2}')
    N_SIZE=$(echo "sqrt(0.9 * $mem / 32)" | bc)
fi

if [[ $P_SIZE == "auto" ]]; then
    P_SIZE=$Sockets
fi

if [[ $NB_SIZE == "auto" ]]; then
    if [[ $ISA == "avx2" ]]; then
        NB_SIZE=240
    else
        NB_SIZE=384
    fi
fi

if [[ $MAP_BY == "socket" ]]; then
    if [[ $Q_SIZE == "auto" ]]; then
        Q_SIZE=1
    fi
    NT=$Cores_Per_Socket
    NR=$Sockets
else
    if [[ $Q_SIZE == "auto" ]]; then
        Q_SIZE=$(( $Numas / $Sockets ))
    fi  
    NT=$Cores_Per_Numa
    NR=$Numas 
fi

sed -e "s/##N##/${N_SIZE}/;s/##B##/${NB_SIZE}/;s/##P##/${P_SIZE}/;s/##Q##/${Q_SIZE}/;" HPL-ref.dat > HPL.dat
ldd ./xhpl > ldd_output.log

tmp_result=$(pwd)/xhpl_"$AMDCPU"_result.txt

echo "N_SIZE is $N_SIZE, NB_SIZE is $NB_SIZE, P_SIZE is $P_SIZE, Q_SIZE is $Q_SIZE"
mpirun --allow-run-as-root --map-by socket:PE=$NT -np $NR \
    -x OMP_NUM_THREADS=$NT -x OMP_PROC_BIND=close -x OMP_PLACES=cores \
    numactl --interleave=all ./xhpl | tee $tmp_result

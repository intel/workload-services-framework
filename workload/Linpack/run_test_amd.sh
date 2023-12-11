#!/bin/bash
N_SIZE=${N_SIZE:-auto}
P_SIZE=${P_SIZE:-auto}
Q_SIZE=${Q_SIZE:-auto}
NB_SIZE=${NB_SIZE:-auto}
ASM=${ASM:-default_instruction}

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

AMD_DIR="amd-zen-hpl-2022_11_automated"
run_xhpl="amd-zen-hpl-avx2-2023_01"
if [[ $ASM == "avx3" ]]; then
    AMD_DIR="amd-zen-hpl-2023_05_16"
    run_xhpl=xhpl
fi

cd /${AMD_DIR}

if [ $N_SIZE == "auto" ]; then
    mem=$(free -b | awk '/Mem:/{print $2}')
    N_SIZE=$(echo "sqrt(0.9 * $mem / 32)" | bc)
fi

if [[ $P_SIZE == "auto" ]]; then
    P_SIZE=$Sockets
fi

if [[ $Q_SIZE == "auto" ]]; then
    Q_SIZE=$(( $Numas / $Sockets ))
fi

if [[ $NB_SIZE == "auto" ]]; then
    if [[ $ASM == "avx3" ]]; then
        NB_SIZE=384
    else
        NB_SIZE=240
    fi
fi

export KMP_AFFINITY=
unset OMPI_MCA_osc

sed -e "s/##N##/${N_SIZE}/;s/##B##/${NB_SIZE}/;s/##P##/${P_SIZE}/;s/##Q##/${Q_SIZE}/;" HPL-ref.dat > HPL.dat
ldd ./xhpl > ldd_output.log

tmp_result=$(pwd)/xhpl_"$AMDCPU"_result.txt

echo "Using this problem size $N_SIZE" 
nodes=$(numactl --show | awk -F: '/^cpubind/ {print $2;}' | sed -e 's/^ //g' -e 's/ $//g' | tr ' ' ',')
mpirun --allow-run-as-root -mca plm rsh --map-by socket:PE=$Cores_Per_Socket -np $Sockets --bind-to core \
    -x OMP_NUM_THREADS=$Cores_Per_Socket -x OMP_PROC_BIND=close -x OMP_PLACES=cores \
    numactl --interleave=${nodes} ./$run_xhpl | tee $tmp_result
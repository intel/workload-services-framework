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

ARMCPU=`lscpu | grep "Model name:" | awk '{print $3,$4,$5,$6,$7}' | tr ' ' '_'`
Sockets=`lscpu | grep "Socket(s):" | awk '{print $2}'`
Threads=`lscpu | grep "CPU(s):     " -m 1 | awk '{print $2}'`
Threads_Per_Core=`lscpu | grep "Thread(s) per core:" | awk '{print $4}'`
Cores=$(( $Threads / $Threads_Per_Core ))
Cores_Per_Socket=$(( $Cores / $Sockets ))

if [ $N_SIZE == "auto" ]; then
    mem=$(free -b | awk '/Mem:/{print $2}')
    N_SIZE=$(echo "sqrt(0.9 * $mem / 32)" | bc)
fi

if [[ $P_SIZE == "auto" ]]; then
    P_SIZE=$Sockets
fi

if [[ $Q_SIZE == "auto" ]]; then
    Q_SIZE=$Cores_Per_Socket
fi

if [[ $NB_SIZE == "auto" ]]; then
    NB_SIZE=192
fi

cd /home/ubuntu/benchmarks/hpl-2.3/bin/Linux_GCCARM_neoverse
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export MODULEPATH=/home/ubuntu/benchmarks/Linpack/modulefiles:$MODULEPATH
source /etc/profile.d/modules.sh
module use /home/ubuntu/benchmarks/Linpack/modulefiles
module load armpl/23.10.0_gcc-12.2

sed -i "5c 1 # of problems sizes (N)" HPL.dat
sed -i "6c ${N_SIZE} Ns" HPL.dat
sed -i "7c 1 # of NBs" HPL.dat
sed -i "8c ${NB_SIZE} NBs" HPL.dat
sed -i "10c 1 # of process grids (P x Q)" HPL.dat
sed -i "11c ${P_SIZE} Ps" HPL.dat
sed -i "12c ${Q_SIZE} Qs" HPL.dat
sed -i "14c 1 # of panel fact" HPL.dat
sed -i "16c 1 # of recursive stopping criterium" HPL.dat
sed -i "20c 1 # of recursive panel fact." HPL.dat
ldd ./xhpl > ldd_output.log

tmp_result=$(pwd)/xhpl_"$ARMCPU"_result.txt

echo "N_SIZE is $N_SIZE, NB_SIZE is $NB_SIZE, P_SIZE is $P_SIZE, Q_SIZE is $Q_SIZE"
mpirun -np ${Cores} --allow-run-as-root ./xhpl

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#Copyright 2017 Intel Corporation.
#
#The source code, information and material ("Material") contained herein is owned
#by Intel Corporation or its suppliers or licensors, and title to such Material
#remains with Intel Corporation or its suppliers or licensors. The Material
#contains proprietary information of Intel or its suppliers and licensors. The
#Material is protected by worldwide copyright laws and treaty provisions.
#No part of the Material may be used, copied, reproduced, modified, published,
#uploaded, posted, transmitted, distributed or disclosed in any way without
#Intel's prior express written permission. No license under any patent, copyright
#or other intellectual property rights in the Material is granted to or conferred
#upon you, either expressly, by implication, inducement, estoppel or otherwise.
#Any license under such intellectual property rights must be express and approved
#by Intel in writing.
#
#Unless otherwise agreed by Intel in writing, you may not remove or alter this
#notice or any other notice embedded in Materials by Intel or Intel's suppliers or
#licensors in any way.

#Note: A copy of the license is included in the LICENSE file that accompanies the
#software.

#################################################################################################
#											    	#
#  Purpose: Runs the xGEMM benchmark with a specified number of threads, problem size, and 	#
#	    math library.									#
#												#
#  Usage: ./run.sh <NUM_THREADS> <SIZE_N> <MATH_LIBRARY>					#
#  												#
#	  NUM_THREADS: Number of threads to run benchmark with.					#
#	  SIZE_N: Problem size to run benchmark with. "all" runs a preselected set of sizes.	#
#	  MATH_LIBRARY: Select "mkl" for Intel(R) Math Kernel Library or "blis" for BLIS*	#
#		        (BLAS-like Library Instantiation Software Framework).			#
#################################################################################################

#!/bin/bash
NUMA="numactl -i all"
# Thread per core
THREADS_PER_CORE=$(lscpu | grep 'Thread(s) per core' | awk '{print $4;}')
# Number of NUMAs
NUMAS_PER_NODE=$(lscpu | grep 'NUMA node(s)' | awk '{print $3;}')
# Number of cores
CORES_PER_NODE=$(lscpu | grep -e '^CPU(s)' | awk '{print $2;}')
# Number of sockets
SOCKETS_PER_NODE=$(lscpu | grep -e '^Socket(s)' | awk '{print $2;}')
# SNC mode (Nodes per socket)
SNC=$(( $NUMAS_PER_NODE / $SOCKETS_PER_NODE ))
# Physical cores per node
PHYSICAL_CORES=$(( $CORES_PER_NODE / $THREADS_PER_CORE ))
# Cores per socket
CORES_PER_SOCKET=$(( $PHYSICAL_CORES / $SOCKETS_PER_NODE ))
# Cores per numa
CORES_PER_NUMA=$(( $PHYSICAL_CORES / $NUMAS_PER_NODE ))

echo "number of physcial cores: ${PHYSICAL_CORES}"
if [[ $OMP_NUM_THREADS == "max" ]]; then
    OMP_NUM_THREADS=$PHYSICAL_CORES
elif [[ $OMP_NUM_THREADS == "socket" ]]; then
    OMP_NUM_THREADS=$CORES_PER_SOCKET
elif [[ $OMP_NUM_THREADS == "numa" ]]; then
    OMP_NUM_THREADS=$CORES_PER_NUMA
elif [[ $OMP_NUM_THREADS == "0" ]]; then
    OMP_NUM_THREADS=$PHYSICAL_CORES
else
  if [[ $OMP_NUM_THREADS -gt $PHYSICAL_CORES ]]; then        # set threads > physical core
    echo "Case setting thread_number:${OMP_NUM_THREADS} is larger than physical core number:$((CORES_PER_NODE / THREADS_PER_CORE)). Reset thread number as physical core number" 
    OMP_NUM_THREADS=$PHYSICAL_CORES
  fi 
fi

if [[ $OMP_NUM_THREADS == 0 ]] || [[ $OMP_NUM_THREADS == "" ]]; then
    OMP_NUM_THREADS=$PHYSICAL_CORES
fi

THREADS_PER_NUMA=$(( $OMP_NUM_THREADS / $NUMAS_PER_NODE ))
REST_THREADS=$(( $OMP_NUM_THREADS - $NUMAS_PER_NODE * $THREADS_PER_NUMA ))
threads_map=0;i=0;j=0
while [ $i -lt $NUMAS_PER_NODE ]
  do  
      interval_start=$(( $i * $CORES_PER_NUMA ))
      interval_end=$(( $i * $CORES_PER_NUMA + $THREADS_PER_NUMA - 1))
      if [[ $i -lt $REST_THREADS ]]; then
          interval_end=$(( $i * $CORES_PER_NUMA + $THREADS_PER_NUMA ))
      fi
      if [[ $interval_start -le $interval_end ]]; then
          threads_map[$j]=$interval_start
          j=$(( $j + 1 ))
          threads_map[$j]=$interval_end
          j=$(( $j + 1 ))
      fi
      i=$(( $i + 1 ))
  done
threads_map_args=`echo $(printf "%d-%d," "${threads_map[@]}")| sed 's/,$//'`  
export KMP_AFFINITY="granularity=thread,proclist=[${threads_map_args}:1],explicit"

if [[ ${MATH_LIB} == "mkl" ]]; then
    export OMP_NUM_THREADS=${OMP_NUM_THREADS}
else
    BLIS_JC_NT=${NUMAS_PER_NODE} 
    BLIS_IC_NT=1
    BLIS_JR_NT=1
    BLIS_IR_NT=1
    if [[ $THREADS_PER_NUMA == 0 ]]; then
        THREADS_PER_NUMA=1
    fi
    THREADS_NUM_SQRT=$(echo | awk "{print sqrt($THREADS_PER_NUMA)}")
    THREADS_NUM_SQRT_FLOOR=`echo "scale=0;$THREADS_NUM_SQRT/1"|bc -l `
    ADD=`awk -v num1=$THREADS_NUM_SQRT_FLOOR -v num2=$THREADS_NUM_SQRT 'BEGIN{print(num1<num2)?"1":"0"}'`
    THREADS_NUM_SQRT_CEIL=$(( $ADD + $THREADS_NUM_SQRT_FLOOR ))
    while [ $THREADS_NUM_SQRT_CEIL -le $THREADS_PER_NUMA ]
      do
          BLIS_IC_NT=$THREADS_NUM_SQRT_CEIL
          BLIS_JR_NT=$(( $THREADS_PER_NUMA / $THREADS_NUM_SQRT_CEIL ))
          if [[ $(( $BLIS_IC_NT * $BLIS_JR_NT )) == $THREADS_PER_NUMA ]]; then
              break
          else
              THREADS_NUM_SQRT_CEIL=$(( $THREADS_NUM_SQRT_CEIL + 1 ))
          fi
      done
    export BLIS_JC_NT=${BLIS_JC_NT} BLIS_IC_NT=${BLIS_IC_NT} BLIS_JR_NT=${BLIS_JR_NT} BLIS_IR_NT=${BLIS_IR_NT}
fi

if [[ ${FLOAT_TYPE} == "sgemm" ]]; then
  if [[ ${MATH_LIB} == "mkl" && -f sgemmbench.mkl ]]; then
    echo "Running using MKL for single precision float; size=${MATRIX_SIZE}; thread_number=${OMP_NUM_THREADS}"
    for size_n in ${MATRIX_SIZE}; do
      echo "${NUMA} ./sgemmbench.mkl ${size_n}"
      ${NUMA} ./sgemmbench.mkl ${size_n}
    done
  elif [[ ${MATH_LIB} == "blis" && -f sgemmbench.blis ]]; then
    echo "Running using BLIS for single precision float; size=${MATRIX_SIZE}; thread_number=${OMP_NUM_THREADS}"
    for size_n in ${MATRIX_SIZE}; do
      echo "${NUMA} ./sgemmbench.blis ${size_n}"
      ${NUMA} ./sgemmbench.blis ${size_n}
    done
  else
    echo "No valid library selected or present; Please, select 'mkl' or 'blis' for libary and make sure you have run Makefile to build the selected library."
  fi
elif [[ ${FLOAT_TYPE} == "dgemm" ]]; then
  if [[ ${MATH_LIB} == "mkl" && -f dgemmbench.mkl ]]; then
    echo "Running using MKL for double precision float; size=${MATRIX_SIZE}; thread_number=${OMP_NUM_THREADS}"
    for size_n in ${MATRIX_SIZE}; do
      echo "${NUMA} ./dgemmbench.mkl ${size_n}"
      ${NUMA} ./dgemmbench.mkl ${size_n}
    done
  elif [[ ${MATH_LIB} == "blis" && -f dgemmbench.blis ]]; then
    echo "Running using BLIS for double precision float;size=${MATRIX_SIZE}; thread_number=${OMP_NUM_THREADS}"
    for size_n in ${MATRIX_SIZE}; do
      echo "${NUMA} ./dgemmbench.blis ${size_n}"
      ${NUMA} ./dgemmbench.blis ${size_n}
    done
  else
    echo "No valid library selected or present; Please, select 'mkl' or 'blis' for libary and make sure you have run Makefile to build the selected library."
  fi
fi
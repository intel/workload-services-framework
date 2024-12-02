#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

INSTRUCTION_SET=${INSTRUCTION_SET:-sse}

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

# default
stream=amd_zen_stream

case "$INSTRUCTION_SET" in
avx3)
  echo "Running stream using amd pre-built zen4 compiler"
  stream=amd_zen_stream
  ;;
*)
  echo -e "\nError: Unknown Instruction Set ${INSTRUCTION_SET}. Valid arguments are: avx3\n"
  exit 1
  ;;
esac

echo "run stream"
./$stream

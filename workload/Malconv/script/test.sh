#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# parse framework and precision requirements and decide with model to use
model='emberMalconv'

if [ "${FRAMEWORK}" != "onnx" ] && [ "${FRAMEWORK}" != "tf" ]; then
    echo "Usage: only onnx and tensorflow are supported"
    exit 1
fi 

if [ "${PRECISION}" != "int8" ] && [ "${PRECISION}" != "bf16" ] && [ "${PRECISION}" != "fp32" ]; then
    echo "Usage: precisions available are int8, bf16 or fp32"
    exit 1
fi 

format=onnx
if [ "${FRAMEWORK}" == "tf" ]; then
    format=pb 
fi 

file=${model}.${PRECISION}.${format}

# see if avx or amx
ISAFlag='ALL'
if [ ${ISA} == "avx" ]
then
    ISAFlag='AVX512_CORE_VNNI'
    if [ "${PRECISION}" == "bf16" ]; then
        ISAFlag='AVX512_CORE_BF16'
    fi
fi

if [ ${ISA} == "amx" ]
then
    ISAFlag='AVX512_CORE_AMX'
fi

if [ ${#TAG} -eq 0 ]; then
    TAG='none'
fi

# start single core / multicore benchmark
if [ ${MODE} == "single" ]; then
    OMP_NUM_THREADS=1 TF_CPP_MIN_LOG_LEVEL=2 DNNL_VERBOSE=0 ONEDNN_VERBOSE=0 TF_ENABLE_ONEDNN_OPTS=1 ONEDNN_MAX_CPU_ISA=${ISAFlag} numactl -C 5 -m 0 python3 malconv_test.py -m ${file} -t ${TAG} -i ./fakeData
    echo "total instance 1"

elif [ ${MODE} != "multi" ]; then
    echo "Usage: mode is either single or multi"
    exit 1

else
    if [ `lscpu | grep Thread | cut -d ':' -f 2 | cut -d ' ' -f 3` -eq 2  ]; then
        echo "Usage: hyperthreading is enabled. Please turn off hyperthreading for multicore benchmark"
        exit 1
    fi 

    if [ ${CORES} -ne 1 ] && [ ${CORES} -ne 2 ] && [ ${CORES} -ne 4 ] && [ ${CORES} -ne 8 ]; then
        echo "Usage: supported core numbers are 1, 2, 4 or 8"
        exit 1
    fi
fi

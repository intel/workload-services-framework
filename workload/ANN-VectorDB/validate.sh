#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ALGORITHM=${1:-milvus}
DATASET=${2:-glove-100-angular}

BATCH=${BATCH:-False}
CPU_LIMIT=${CPU_LIMIT:-8}
MEM_LIMIT=${MEM_LIMIT:-16}
# PARALLELISM=${PARALLELISM:-1}

# Milvus configuration
MILVUS_M=${MILVUS_M:-96}
MILVUS_QUERY_ARGS=${MILVUS_QUERY_ARGS:-800}
if [[ "${TESTCASE}" =~ ^test.*_gated$ ]]; then
    ALGORITHM="milvus"
    MILVUS_QUERY_ARGS=10
fi

# FAISS configuration
FAISS_NAME=${FAISS_NAME:-float_faiss_ivfpqfs}
FAISS_ARGS=${FAISS_ARGS:-4096}
FAISS_QUERY_ARGS=${FAISS_QUERY_ARGS:-200}
FAISS_QUERY_ARGS2=${FAISS_QUERY_ARGS2:-1000}

# Redisearch configuration
REDISEARCH_ARG_GROUP=${REDISEARCH_ARG_GROUP:-96}
REDISEARCH_QUERY_ARGS=${REDISEARCH_QUERY_ARGS:-800}

# HNSWlib configuration
HNSWLIB_ARG_GROUP=${HNSWLIB_ARG_GROUP:-96}
HNSWLIB_QUERY_ARGS=${REDISEARCH_QUERY_ARGS:-800}

PLATFROM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-ann-vectordb}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

#Event tracing parameters
if [[ "${TESTCASE}" =~ ^test.*_pkm$ ]]; then
    EVENT_TRACE_PARAMS="roi,Begin performance testing,End performance testing"
fi

case $PLATFORM in
    ARMv8 | ARMv9 )
        IMAGE_ARCH="-arm64"
        ;;
    MILAN | ROME )
        IMAGE_ARCH=""
        ;;
    * )
        IMAGE_ARCH=""
        ;;
esac

# Workload Setting
WORKLOAD_PARAMS=(
    ALGORITHM DATASET BATCH CPU_LIMIT MEM_LIMIT 
    MILVUS_M MILVUS_QUERY_ARGS 
    FAISS_NAME FAISS_ARGS FAISS_QUERY_ARGS FAISS_QUERY_ARGS2
    REDISEARCH_ARG_GROUP REDISEARCH_QUERY_ARGS
    HNSWLIB_ARG_GROUP HNSWLIB_QUERY_ARGS
    PLATFROM WORKLOAD
)

# Kubernetes Setting
# RECONFIG_OPTIONS=""

# JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"


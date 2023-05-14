#!/bin/bash -e

OPTION=${1:-inference_throughput_amx_bfloat16}
PLATFORM=${PLATFORM:-SPR}
STEPS=${STEPS:-30}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-}
INSTANCE_NUMBER=${INSTANCE_NUMBER:-}
TOPOLOGY="bert_large"
PRECISION=${PRECISION:-avx_fp32}
DATA_TYPE=${DATA_TYPE:-real}
MAX_SEQ_LENGTH=${MAX_SEQ_LENGTH:-384}
WARMUP_STEPS=${WARMUP_STEPS:-15}
WEIGHT_SHARING=${WEIGHT_SHARING:-False}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}

BATCH_SIZE=${BATCH_SIZE:-1}
FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
PRECISION=$(echo ${OPTION}|cut -d_ -f3-4)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f5)
CUSTOMER_ENV=${CUSTOMER_ENV}

if [ -n "$CASE_TYPE" ] && [ "$CASE_TYPE" == "pkm" ]; then
    if [ "$MODE" == "throughput" ]; then
        EVENT_TRACE_PARAMS="roi,Start case topology,Finish case topology"
    fi
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(MODE PLATFORM TOPOLOGY PRECISION FUNCTION DATA_TYPE WARMUP_STEPS STEPS BATCH_SIZE CORES_PER_INSTANCE INSTANCE_NUMBER WEIGHT_SHARING ONEDNN_VERBOSE ENABLE_PROFILING MAX_SEQ_LENGTH CUSTOMER_ENV)

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.${FUNCTION}"
DOCKER_OPTIONS="--privileged -e MODE=${MODE} -e PLATFORM=${PLATFORM} \
                -e TOPOLOGY=${TOPOLOGY} -e PRECISION=${PRECISION} \
                -e FUNCTION=${FUNCTION} -e DATA_TYPE=${DATA_TYPE} \
                -e STEPS=${STEPS} -e BATCH_SIZE=${BATCH_SIZE} -e WARMUP_STEPS=${WARMUP_STEPS} \
                -e CORES_PER_INSTANCE=${CORES_PER_INSTANCE} \
                -e INSTANCE_NUMBER=${INSTANCE_NUMBER} -e ONEDNN_VERBOSE=${ONEDNN_VERBOSE} \
                -e ENABLE_PROFILING=${ENABLE_PROFILING} -e MAX_SEQ_LENGTH=${MAX_SEQ_LENGTH} \
                -e WEIGHT_SHARING=${WEIGHT_SHARING} -e CUSTOMER_ENV=${CUSTOMER_ENV}"


# Kubernetes Setting
RECONFIG_OPTIONS="-DK_TOPOLOGY=${TOPOLOGY} -DK_MODE=${MODE} -DK_PLATFORM=${PLATFORM} \
                  -DK_PRECISION=${PRECISION} -DK_FUNCTION=${FUNCTION} \
                  -DK_DATA_TYPE=${DATA_TYPE} -DK_STEPS=${STEPS} \
                  -DK_BATCH_SIZE=${BATCH_SIZE} -DK_WARMUP_STEPS=${WARMUP_STEPS} \
                  -DK_CORES_PER_INSTANCE=${CORES_PER_INSTANCE} \
                  -DK_INSTANCE_NUMBER=${INSTANCE_NUMBER} \
                  -DK_ONEDNN_VERBOSE=${ONEDNN_VERBOSE} \
                  -DK_ENABLE_PROFILING=${ENABLE_PROFILING} \
                  -DK_MAX_SEQ_LENGTH=${MAX_SEQ_LENGTH} \
                  -DK_WEIGHT_SHARING=${WEIGHT_SHARING} -DK_CUSTOMER_ENV=${CUSTOMER_ENV}"
                  
JOB_FILTER="job-name=bertlarge-pytorch-xeon-public-benchmark"

. "$DIR/../../script/validate.sh"
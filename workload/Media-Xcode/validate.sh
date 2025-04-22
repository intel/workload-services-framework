#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-SVT-AV1-1080p-8-avx2_gcc}
TOOL=${2:-ffmpeg}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-mediaxcode}
IMAGEARCH=${IMAGEARCH:-linux/amd64}
NUMACTL=${NUMACTL:-1}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-auto}
CORES_LIST=${CORES_LIST:-auto}
NUMA_MEM_SET=${NUMA_MEM_SET:-auto}
MODE=${MODE}
HT=${HT:-1}
VIDEOCLIP=${VIDEOCLIP}
CLIP_EXTRACT_DURATION=${CLIP_EXTRACT_DURATION:-auto}

CONFIG_FILE=${CONFIG_FILE:-pkb_2.0_config.yaml}
CLIP_EXTRACT_FRAME=${CLIP_EXTRACT_FRAME:-auto}
echo $NUMACTL $MODE $CORES_PER_INSTANCE $HT $VIDEOCLIP $CLIP_EXTRACT_DURATION $CLIP_EXTRACT_FRAME $CORES_LIST $NUMA_MEM_SET $CONFIG_FILE

ARCH=${IMAGEARCH/*\//}
USECASE=$(echo ${OPTION}|cut -d_ -f1)
COMPILER=$(echo ${OPTION}|cut -d_ -f2)

if [ -z ${MODE} ]; then
    MODE=$(echo ${OPTION}|cut -d_ -f3)
fi

GATE_TEST=$(echo ${OPTION}|cut -d_ -f4)

#AVX_TYPE=$(echo ${USECASE}|rev|cut -d- -f1|rev)
#if [ -z ${AVX_TYPE} ]; then
#    AVX_TYPE=$(echo ${USECASE}|cut -d- -f4)
#fi

if [[ "$USECASE" != "all-avx2" &&  "$USECASE" != "ffmpeg-all" ]]; then
    EVENT_TRACE_PARAMS="roi,start_ffmpeg_processes+30s,+30s"
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# case $AVX_TYPE in
#     avx2 | avx3 )
#         IMAGE_TYPE="-amd64"${COMPILER}-${AVX_TYPE}
#         ;;
#     * )
#         IMAGE_TYPE="-amd64"${COMPILER}-avx2
# esac

IMAGE_TYPE="-amd64"${COMPILER}

# if [ -e "$DIR/$PLATFORM-validate.sh" ]; then
#    . "$DIR/$PLATFORM-validate.sh"
# fi

# Add FFmpeg version v44/v60
# IMAGE_TYPE=${WORKLOAD/*-/}$IMAGE_TYPE

# Workload Setting
WORKLOAD_PARAMS=(USECASE TOOL MODE COMPILER ARCH IMAGE_TYPE NUMACTL CORES_PER_INSTANCE HT VIDEOCLIP CLIP_EXTRACT_DURATION CLIP_EXTRACT_FRAME CORES_LIST)

# Docker Setting
FFMPEG_VERSION=$(echo ${WORKLOAD}|cut -d- -f3)
FFMPEG_OS=$(echo ${WORKLOAD}|cut -d- -f4)
DOCKER_IMAGE="media-xcode-$FFMPEG_VERSION$IMAGE_TYPE-$FFMPEG_OS"
DOCKER_PROXY_OPTIONS=" -e HTTP_PROXY=$HTTP_PROXY -e HTTPS_PROXY=$HTTPS_PROXY -e http_proxy=$http_proxy -e https_proxy=$https_proxy "
DOCKER_OPTIONS="--privileged --net=host -e USECASE=${USECASE} -e TOOL=${TOOL} -e ARCH=${ARCH} -e COMPILER=${COMPILER} -e MODE=${MODE} -e IMAGE_TYPE=${IMAGE_TYPE} -e NUMACTL=${NUMACTL} -e CORES_PER_INSTANCE=${CORES_PER_INSTANCE} -e HT=${HT} -e VIDEOCLIP=${VIDEOCLIP} -e CLIP_EXTRACT_DURATION=${CLIP_EXTRACT_DURATION} -e CLIP_EXTRACT_FRAME=${CLIP_EXTRACT_FRAME} -e CORES_LIST=${CORES_LIST} -e CONFIG_FILE=${CONFIG_FILE} -e NUMA_MEM_SET=${NUMA_MEM_SET} -e DOCKER_IMAGE=${DOCKER_IMAGE} -v /etc/localtime:/etc/localtime:ro"

# Kubernetes Setting
K8S_PROXY_OPTIONS=" -DK_HTTP_PROXY=$HTTP_PROXY -DK_HTTPS_PROXY=$HTTPS_PROXY -DK_http_proxy=$http_proxy -DK_https_proxy=$https_proxy "
RECONFIG_OPTIONS="-DK_USECASE=${USECASE} -DK_TOOL=${TOOL} -DK_ARCH=${ARCH} -DK_COMPILER=${COMPILER} -DK_MODE=${MODE} -DK_IMAGE_TYPE=${IMAGE_TYPE} -DK_NUMACTL=${NUMACTL} -DK_CORES_PER_INSTANCE=${CORES_PER_INSTANCE} -DK_HT=${HT} -DK_VIDEOCLIP=${VIDEOCLIP} -DK_CLIP_EXTRACT_DURATION=${CLIP_EXTRACT_DURATION} -DK_CLIP_EXTRACT_FRAME=${CLIP_EXTRACT_FRAME} -DK_CORES_LIST=${CORES_LIST} -DK_CONFIG_FILE=${CONFIG_FILE} -DK_NUMA_MEM_SET=${NUMA_MEM_SET} -DK_DOCKER_IMAGE=${DOCKER_IMAGE}"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"


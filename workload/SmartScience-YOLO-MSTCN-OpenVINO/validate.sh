#!/bin/bash -e

WORKLOAD=${WORKLOAD:-SmartScienceLab}
INSTANCE_COUNT=${INSTANCE_COUNT:="1"}
AI_DEVICE=${AI_DEVICE:="CPU"}
DATABASE=${DATABASE:="offline"} 
VIDEO_DECODE=${VIDEO_DECODE:="CPU"}
CLUSTER_NODES=${CLUSTER_NODES:-2}

if [ $(echo ${TESTCASE} | grep "fps_inference_gated") ]; then
    CLUSTER_NODES=1
    INSTANCE_COUNT=1
fi

if [ $(echo ${TESTCASE} | grep "video_decode_GPU") ]; then
    VIDEO_DECODE="GPU"
fi


# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(DATABASE VIDEO_DECODE AI_DEVICE)

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.instance"
DOCKER_OPTIONS="-e DATABASE=$DATABASE -e VIDEO_DECODE=$VIDEO_DECODE -e AI_DEVICE=$AI_DEVICE"


# Kubernetes Setting
RECONFIG_OPTIONS="-DK_DATABASE=$DATABASE -DK_VIDEO_DECODE=$VIDEO_DECODE -DK_INSTANCE_COUNT=$INSTANCE_COUNT -DK_AI_DEVICE=$AI_DEVICE -DCLUSTERNODE=$CLUSTER_NODES"
JOB_FILTER="name=benchmark"


. "$DIR/../../script/validate.sh"    

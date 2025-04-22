#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

FFMPEG_VERSION=$(echo ${WORKLOAD}|cut -d- -f3)
FFMPEG_OS=$(echo ${WORKLOAD}|cut -d- -f4)
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
if [[ $FFMPEG_OS == "ubuntu2204"  ]]; then
   STACK="ffmpeg_${FFMPEG_VERSION}" "$DIR/../../stack/FFmpeg/build.sh" $@
else
   STACK="ffmpeg_ubuntu2404_${FFMPEG_VERSION}" "$DIR/../../stack/FFmpeg_ubuntu2404/build.sh" $@
fi

M4_OPTIONS="-DVERSION=${FFMPEG_VERSION}"
FIND_OPTIONS="( -name Dockerfile.?.*aocc.${FFMPEG_OS}.tmpm4* -o -name Dockerfile.?.*gcc.${FFMPEG_OS}.tmpm4* )"
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX}"

if [ -e "$DIR/$PLATFORM-build.sh" ]; then
   . "$DIR/$PLATFORM-build.sh"
fi

. "$DIR/../../script/build.sh"


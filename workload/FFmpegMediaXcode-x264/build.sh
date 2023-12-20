#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
STACK="ffmpeg_${WORKLOAD/*-/}" "$DIR/../../stack/FFmpeg/build.sh" $@

M4_OPTIONS="-DVERSION=${WORKLOAD/*-/}"
FIND_OPTIONS="( -name Dockerfile.?.*avx2.tmpm4* -o -name Dockerfile.?.*avx3.tmpm4* )"
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX}"


if [ -e "$DIR/$PLATFORM-build.sh" ]; then
   . "$DIR/$PLATFORM-build.sh"
fi

. "$DIR/../../script/build.sh"


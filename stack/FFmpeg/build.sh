#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
DOCKER_CONTEXT="${STACK/*_/}"

FIND_OPTIONS="( -name Dockerfile.?.${STACK#*_}.dataset -o -name Dockerfile.?.${STACK#*_}.ffmpeg* -o -name Dockerfile.?.${STACK#*_}.*avx2 -o -name Dockerfile.?.${STACK#*_}.*avx3 )"

if [ -e "$DIR/$PLATFORM-build.sh" ]; then
   . "$DIR/$PLATFORM-build.sh"
fi

. "$DIR/../../script/build.sh"


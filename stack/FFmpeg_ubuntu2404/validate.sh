#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTIONS=${1:-avx2}
VERSION=${STACK#*_}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(OPTIONS VERSION)

# Docker Setting
DOCKER_IMAGE="$(ls -1 "$DIR"/${VERSION}/Dockerfile.1.${VERSION}.ffmpeg.${OPTIONS}.unittest)"
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DOPTIONS=${OPTIONS} -DVERSION=${VERSION}"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"


#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"

WORKLOAD=${WORKLOAD:-"stream"}
if [[ "$WORKLOAD" == *_amd_* ]]; then
  FIND_OPTIONS="(  -name Dockerfile.1.stream.amd*  -o -name Dockerfile.1.stream.base* )"
elif [[ "$WORKLOAD" == *_arm_* ]]; then
  FIND_OPTIONS="( -name Dockerfile.1.stream.arm*  -o -name Dockerfile.1.stream.base* )"
else
  FIND_OPTIONS="( -name Dockerfile.1.stream.ic* -o -name Dockerfile.1.stream.base* )"
fi

echo "FIND_OPTIONS=$FIND_OPTIONS"

. "$DIR"/../../script/build.sh

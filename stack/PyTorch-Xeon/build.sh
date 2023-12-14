#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK=${STACK:-pytorch_xeon_public}

FIND_OPTIONS="-name Dockerfile.?.${STACK}"

if [ -e "$DIR/Dockerfile.?.${STACK}.unittest" ]; then
    FIND_OPTIONS="( -name Dockerfile.?.${STACK}.unittest $FIND_OPTIONS )"
fi

. "$DIR"/../../script/build.sh

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK=${STACK:-pytorch_xeon_public_24.04}

FIND_OPTIONS="-name Dockerfile.?.${STACK}"

if [ -e "$DIR/Dockerfile.?.${STACK}.unittest_24.04" ]; then
    FIND_OPTIONS="( -name Dockerfile.?.${STACK}.unittest_24.04 $FIND_OPTIONS )"
fi

. "$DIR"/../../script/build.sh

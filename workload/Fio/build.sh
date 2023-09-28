#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"


if [ -e "$DIR"/Dockerfile.1.${PLATFORM,,} ]; then
    FIND_OPTIONS=" -name Dockerfile.1.${PLATFORM,,} "
elif [[ "$PLATFORM" == ARMv8 || "$PLATFORM" == ARMv9 ]]; then
    FIND_OPTIONS=" -name Dockerfile.1.arm "
else
    FIND_OPTIONS=" -name Dockerfile "
fi

FIND_OPTIONS="( $FIND_OPTIONS )"

. "$DIR"/../../script/build.sh

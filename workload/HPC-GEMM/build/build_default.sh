#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

SINGLE_BLIS_NC=3072
SINGLE_BLIS_KC=384
SINGLE_BLIS_MC=480
DOUBLE_BLIS_NC=3752
DOUBLE_BLIS_KC=256
DOUBLE_BLIS_MC=240

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SINGLE_BLIS_NC=$SINGLE_BLIS_NC --build-arg SINGLE_BLIS_KC=$SINGLE_BLIS_KC --build-arg SINGLE_BLIS_MC=$SINGLE_BLIS_MC --build-arg DOUBLE_BLIS_NC=$DOUBLE_BLIS_NC --build-arg DOUBLE_BLIS_KC=$DOUBLE_BLIS_KC --build-arg DOUBLE_BLIS_MC=$DOUBLE_BLIS_MC"

FIND_OPTIONS="( -name Dockerfile.1.srf )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

SINGLE_BLIS_NC=4008
SINGLE_BLIS_KC=680
SINGLE_BLIS_MC=256
DOUBLE_BLIS_NC=4004
DOUBLE_BLIS_KC=340
DOUBLE_BLIS_MC=256

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SINGLE_BLIS_NC=$SINGLE_BLIS_NC --build-arg SINGLE_BLIS_KC=$SINGLE_BLIS_KC --build-arg SINGLE_BLIS_MC=$SINGLE_BLIS_MC --build-arg DOUBLE_BLIS_NC=$DOUBLE_BLIS_NC --build-arg DOUBLE_BLIS_KC=$DOUBLE_BLIS_KC --build-arg DOUBLE_BLIS_MC=$DOUBLE_BLIS_MC"

FIND_OPTIONS="( -name Dockerfile )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

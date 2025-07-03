#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

SINGLE_BLIS_NC=20004
SINGLE_BLIS_KC=750
SINGLE_BLIS_MC=416
DOUBLE_BLIS_NC=20006
DOUBLE_BLIS_KC=336
DOUBLE_BLIS_MC=464

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SINGLE_BLIS_NC=$SINGLE_BLIS_NC --build-arg SINGLE_BLIS_KC=$SINGLE_BLIS_KC --build-arg SINGLE_BLIS_MC=$SINGLE_BLIS_MC --build-arg DOUBLE_BLIS_NC=$DOUBLE_BLIS_NC --build-arg DOUBLE_BLIS_KC=$DOUBLE_BLIS_KC --build-arg DOUBLE_BLIS_MC=$DOUBLE_BLIS_MC"

FIND_OPTIONS="( -name Dockerfile )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

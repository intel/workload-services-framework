#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

VER_NUM="2022_11_automated"
DOCKER_IMAGE="$DIR/Dockerfile.1.amd.unittest"

WORKLOAD_PARAMS=(VER_NUM)

DOCKER_OPTIONS="--privileged --shm-size=4gb -e VER_NUM=$VER_NUM"
RECONFIG_OPTIONS="-DDOCKER_IMAGE=$DOCKER_IMAGE -DK_SHM_SIZE=4gb -DK_VER_NUM=$VER_NUM"

. "$DIR/../../script/validate.sh"
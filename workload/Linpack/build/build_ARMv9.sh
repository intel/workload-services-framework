#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.1.arm*"

BUILD_ARCH=Linux_GCCARM_neoverse-512
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg ARM_ARCH=${BUILD_ARCH}"

. $DIR/../../script/build.sh
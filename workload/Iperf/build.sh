#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IPERF_VER=${WORKLOAD#iperf}"
. "$DIR"/../../script/build.sh

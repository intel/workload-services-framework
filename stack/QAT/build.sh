#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
FIND_OPTIONS="( -name Dockerfile.*.${STACK//_/-}* )"
. "$DIR"/../../script/build.sh

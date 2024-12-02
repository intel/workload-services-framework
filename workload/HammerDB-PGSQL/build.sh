#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
suffix="${WORKLOAD//*_/}"
FIND_OPTIONS="( -name Dockerfile.1.${suffix}.hammerdb -o -name Dockerfile.2.postgresql )"

. "$DIR"/../../script/build.sh
#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd -P )"

STACK=" " $DIR/../../stack/Linpack/build.sh $@

if [ -e "$DIR/build/build_${PLATFORM}.sh" ]; then
    . $DIR/build/build_${PLATFORM}.sh
fi
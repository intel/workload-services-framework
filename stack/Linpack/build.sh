#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [ -e "$DIR/../../stack/Linpack/build/build_${PLATFORM}.sh" ]; then
    . $DIR/../../stack/Linpack/build/build_${PLATFORM}.sh
fi
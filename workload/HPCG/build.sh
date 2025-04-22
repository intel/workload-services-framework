#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [ -e ${DIR}/build_${PLATFORM}.sh ]; then
    . ${DIR}/build_${PLATFORM}.sh
else
    . ${DIR}/build_default.sh
fi

. "$DIR"/../../script/build.sh

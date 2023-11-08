#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [ -e ${DIR}/Dockerfile.1.internal ]; then
    FIND_OPTIONS="( -name Dockerfile.1.internal $FIND_OPTIONS )"
else
    FIND_OPTIONS="( -name Dockerfile.1.external $FIND_OPTIONS )"
fi

. "$DIR"/../../script/build.sh

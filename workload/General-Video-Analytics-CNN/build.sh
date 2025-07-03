#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [[ -e "$DIR"/Dockerfile.2.arl.int ]]; then
    if [[ $WORKLOAD =~ bmg ]]; then
        M4_OPTIONS=" -DDEVICE=-bmg "
        FIND_OPTIONS="( -name Dockerfile.2.${PLATFORM,,}.bmg.int -o -name Dockerfile.1.*.int.* ) -a "
    else
        M4_OPTIONS=" -DDEVICE= "
        FIND_OPTIONS="( -name Dockerfile.2.${PLATFORM,,}.int -o -name Dockerfile.1.*.int.* ) -a ! -name *bmg -a "
    fi
else
    M4_OPTIONS=" -DDEVICE= "
    FIND_OPTIONS="( -name Dockerfile.3.datasets -o -name Dockerfile.2.${PLATFORM,,}* -o -name Dockerfile.1.* ) -a ! -name *bmg ! -name *int*"
fi

FIND_OPTIONS="( $FIND_OPTIONS )"
. "$DIR/../../script/build.sh"

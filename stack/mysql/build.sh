#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
USECASE=${USECASE:-"oh"}

case $PLATFORM in
    ARMv8 | ARMv9 )
        if [[ $USECASE == "multi" ]]; then
            FIND_OPTIONS="( -name Dockerfile.?.mysql.${USECASE} $FIND_OPTIONS )"
        else
            FIND_OPTIONS="( -name Dockerfile.?.mysql.arm.${USECASE} $FIND_OPTIONS )"
        fi
        ;;
    * )
        FIND_OPTIONS="( -name Dockerfile.?.mysql.${USECASE}* $FIND_OPTIONS )"
        ;;
esac

. "$DIR/../../script/build.sh"

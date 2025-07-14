#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

case $PLATFORM in
    ARMv8 | ARMv9 )
        CHARMARCH=arm8
        ARCHSETTING=aarch64
        ;;
    MILAN | ROME | GENOA )
        CHARMARCH=linux-x86_64
        ARCHSETTING=x86_64
        ;;
    * )
        CHARMARCH=linux-x86_64
        ARCHSETTING=x86_64
        ;;
esac

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="${WORKLOAD#*_}" "$DIR/../../stack/MongoDB/build.sh" $@
BUILD_OPTIONS="$BUILD_OPTIONS  --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"
FIND_OPTIONS="( -name Dockerfile.1.mongodb.tmpm4.* -o -name Dockerfile.2.ycsb.tmpm4.* )"

. "$DIR"/../../script/build.sh

if [[ -e "$DIR/${BACKEND}-config/build.sh" ]]; then
    . "$DIR/${BACKEND}-config/build.sh" $@
fi
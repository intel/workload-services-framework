#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

STACK=${STACK:-"mongodb441_base"}

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

USECASE=$(echo $STACK | cut -d_ -f2)
MONGODB_VER=$(echo $STACK | cut -d_ -f1)

BUILD_OPTIONS="$BUILD_OPTIONS  --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
if [[ "$USECASE" == *qat* ]]; then
    STACK="qathw-ssl3-ubuntu-latest" "$DIR/../../stack/QAT/build.sh" $@
fi

case $PLATFORM in
    ARMv8 | ARMv9 )
        FIND_OPTIONS="( -name Dockerfile.?.arm64${MONGODB_VER}.${USECASE}* $FIND_OPTIONS )"
        ;;
    * )
        FIND_OPTIONS="( -name Dockerfile.?.amd64${MONGODB_VER}.${USECASE}* $FIND_OPTIONS )"
        ;;
esac

. "$DIR"/../../script/build.sh
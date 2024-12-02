#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# build platform based server
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
FIND_OPTIONS_RAW="$FIND_OPTIONS"
BUILD_OPTIONS_RAW="$BUILD_OPTIONS"

SUFFIX="${WORKLOAD//*_/}"

BUILD_OPTIONS="$BUILD_OPTIONS  --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"
FIND_OPTIONS="( -name Dockerfile.3.${SUFFIX} $FIND_OPTIONS )"

if [[ -e "$DIR/${BACKEND}-config/build.sh" ]]; then
    . "$DIR/${BACKEND}-config/build.sh" $@    
fi

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

# build x86 client
IMAGEARCH=linux/amd64
CHARMARCH=linux-x86_64
ARCHSETTING=x86_64
FIND_OPTIONS="( -name Dockerfile.*.${SUFFIX}* $FIND_OPTIONS_RAW)"

BUILD_OPTIONS="$BUILD_OPTIONS_RAW --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. $DIR/../../script/build.sh
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
    MILAN | ROME | GENOA)
        CHARMARCH=linux-x86_64
        ARCHSETTING=x86_64
        ;; 
    * )
        CHARMARCH=linux-x86_64
        ARCHSETTING=x86_64
        ;;       
esac

case $IMAGEARCH in
    "linux/amd64"* )
        IMAGESUFFIX=""
        FIND_OPTIONS="( -name Dockerfile*64 $FIND_OPTIONS )"
        ;;
    * )
        IMAGESUFFIX="-"${IMAGEARCH/*\//}
        FIND_OPTIONS="( -name Dockerfile*amdaarch64 $FIND_OPTIONS )"
        ;;
esac

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="Cassandra" "$DIR"/../../stack/Cassandra/build.sh $@

BUILD_OPTIONS="$BUILD_OPTIONS  --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING --build-arg IMAGESUFFIX=$IMAGESUFFIX"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh
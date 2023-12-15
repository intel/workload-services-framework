#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

case $IMAGEARCH in
    "linux/amd64"* )
        IMAGESUFFIX=""
        JDKTAG="x64"        
        ;;
    * )
        IMAGESUFFIX="-"${IMAGEARCH/*\//}
        JDKTAG="aarch64"
        ;;
esac

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX} --build-arg JDKTAG=${JDKTAG}"

case $PLATFORM in
    ARMv8 | ARMv9 )
        FIND_OPTIONS="( -name *amdaarch64 $FIND_OPTIONS )"
        ;;
    * )
esac

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh
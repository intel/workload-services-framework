#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

case $PLATFORM in
    ARMv* )
        JDKARCH=aarch64
        ;;
    * )
        JDKARCH=x64
        ;;
esac

case $IMAGEARCH in
    "linux/amd64"* )
        IMAGESUFFIX=""
        ;;
    * )
        IMAGESUFFIX="-"${IMAGEARCH/*\//}
        ;;
esac

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX} --build-arg JDKARCH=${JDKARCH} --build-arg JDKVER=${STACK/*jdk/} "
FIND_OPTIONS="( ! -name *.m4 $FIND_OPTIONS )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

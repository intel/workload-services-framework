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

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK=$(echo $STACK | sed 's/[^-]*-\(.*\)-.*/\1/')-${STACK/*jdk/} "$DIR"/../JDK/build.sh $@

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX} --build-arg JDKARCH=${JDKARCH} --build-arg JDKVER=${STACK/*jdk/} --build-arg JDKVENDOR=$(echo $STACK | sed 's/[^-]*-\(.*\)-.*/\1/') "

. "$DIR"/../../script/build.sh

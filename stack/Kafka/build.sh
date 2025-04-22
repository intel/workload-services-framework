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

JDK_STACK=$(echo $STACK | cut -d'-' -f2-3 | sed 's/jdk\([^jdk]*\)$/\1/')

if [[ $STACK == *"ubuntu24"* ]]; then        
    STACK=$JDK_STACK "$DIR"/../UBUNTU2404_JDK/build.sh $@ 
    OS_SUFFIX="-ubuntu24"
else            
    STACK=$JDK_STACK "$DIR"/../JDK/build.sh $@
    OS_SUFFIX=""
fi

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX} --build-arg JDKARCH=${JDKARCH} --build-arg JDKVER=$(echo $STACK | sed -n 's/.*jdk\([0-9]\+\).*/\1/p') --build-arg JDKVENDOR=$(echo $STACK | sed -n 's/^[^-]*-\([^-]*\)-jdk.*/\1/p') --build-arg OS_SUFFIX=${OS_SUFFIX} "

. "$DIR"/../../script/build.sh

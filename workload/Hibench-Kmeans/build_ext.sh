#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BUILD_OPTIONS="--build-arg HTTP_PROXY_ADDRESS=$(echo $http_proxy | sed 's|^.*://||' | cut -f1 -d:) \
--build-arg HTTP_PROXY_PORT=$(echo $http_proxy | sed 's|^.*://||' | cut -f2 -d: | tr -dc '0-9') \
--build-arg HTTPS_PROXY_ADDRESS=$(echo $https_proxy | sed 's|^.*://||' | cut -f1 -d:) \
--build-arg HTTPS_PROXY_PORT=$(echo $https_proxy | sed 's|^.*://||' | cut -f2 -d: | tr -dc '0-9')"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
if [ -e "$DIR/Dockerfile.3.hibench_node" ]; then
    FIND_OPTIONS="( -name Dockerfile.1.client -o -name Dockerfile.2.client.base -o -name Dockerfile.3.hibench_node )"
else
    FIND_OPTIONS="( -name Dockerfile.1.client -o -name Dockerfile.2.client.base -o -name Dockerfile.3.hibench_node_ext )"
fi
find . \( $FIND_OPTIONS \) -print
case $PLATFORM in
    ARMv* )
        JDKARCH=aarch64
        JDKVER=8u432
        BACKPORT_NUM=b06
        ;;
    * )
        JDKARCH=x64
        JDKVER=8u422
        BACKPORT_NUM=b05
        ;;
esac

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX} --build-arg JDKARCH=${JDKARCH} --build-arg BACKPORT_NUM=${BACKPORT_NUM} --build-arg JDKVER=${JDKVER} "

. $DIR/../../script/build.sh

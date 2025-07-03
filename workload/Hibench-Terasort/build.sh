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
. $DIR/../../script/build.sh
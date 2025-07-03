#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [[ $WORKLOAD == *"ubuntu2404"* ]]; then
    FIND_OPTIONS="( -name *.ubuntu2404 )"
else
    FIND_OPTIONS="( ! -name *.ubuntu2404 )"
fi

DJANGO_PROJECT_REPO="${DJANGO_PROJECT_REPO}"
DJANGO_PROJECT_VER="${DJANGO_PROJECT_VER}"

if [[ -n "${DJANGO_PROJECT_REPO}" && -n "${DJANGO_PROJECT_VER}" ]]; then
    BUILD_OPTIONS="$BUILD_OPTIONS --build-arg DJANGO_PROJECT_REPO=${DJANGO_PROJECT_REPO} --build-arg DJANGO_PROJECT_VER=${DJANGO_PROJECT_VER}"
fi

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

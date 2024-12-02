#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-pytorch_xeon_public_version_check}
VERSION=$(echo ${OPTION}|cut -d_ -f3)

case ${VERSION} in
    "public" )
        VERSION=intel_public
    ;;
    "dev" )
        VERSION=intel_dev
    ;;
    * )
        :
    ;;
esac

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(VERSION)

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.${VERSION}.unittest"
DOCKER_OPTIONS="--privileged -e VERSION=${VERSION}"
RECONFIG_OPTIONS="-DK_VERSION=${VERSION}"

JOB_FILTER="job-name=pytorch-public-version-check"

. "$DIR/../../script/validate.sh"
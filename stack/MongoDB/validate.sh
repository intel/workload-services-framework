#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

MONGODB_VERSION=${MONGODB_VERSION:="6.0.4"}
INTEL_FEATURE=${INTEL_FEATURE:="base"}
PLATFORM=${PLATFORM:="SPR"}

case $PLATFORM in
    ARMv8 | ARMv9 )
        ARCH=arm64
        ;;
    * )
        ARCH=amd64
        ;;
esac

OPTIONS="${ARCH}mongodb${MONGODB_VERSION//./}.${INTEL_FEATURE}"

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(OPTIONS)

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DOPTIONS=${OPTIONS}"
JOB_FILTER="job-name=unittest"

. "$DIR/../../script/validate.sh"
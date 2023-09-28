#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-speccpu_2017_v119}
IMAGEARCH=${IMAGEARCH:-linux/arm64}

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [[ $WORKLOAD = *nda* ]]; then
    SPEC2017_ISO_VER="${SPEC2017_ISO_VER:-1.1.9}"
    SPEC_CPU_PKG="${SPEC_CPU_PKG}"

    SPEC_CPU_ICC_BINARIES_VER="${SPEC_CPU_ICC_BINARIES_VER:-ic2023.0-linux-binaries-20221201}"
    SPEC_CPU_ICC_BINARIES_REPO="${SPEC_CPU_ICC_BINARIES_REPO}"

    SPEC_CPU_GCC_BINARIES_VER="${SPEC_CPU_GCC_BINARIES_VER:-gcc12.1.0-lin-binaries-20220509}"
    SPEC_CPU_GCC_BINARIES_REPO="${SPEC_CPU_GCC_BINARIES_REPO}"

    if [ -n "${SPEC_CPU_PKG}" ]; then
        BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SPEC2017_ISO_VER=${SPEC2017_ISO_VER} --build-arg SPEC_CPU_PKG=${SPEC_CPU_PKG}"
    fi

    if [ -n "${SPEC_CPU_ICC_BINARIES_REPO}" ]; then
        BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SPEC_CPU_ICC_BINARIES_VER=${SPEC_CPU_ICC_BINARIES_VER} --build-arg SPEC_CPU_ICC_BINARIES_REPO=${SPEC_CPU_ICC_BINARIES_REPO}"
    fi

    if [ -n "${SPEC_CPU_GCC_BINARIES_REPO}" ]; then
        BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SPEC_CPU_GCC_BINARIES_VER=${SPEC_CPU_GCC_BINARIES_VER} --build-arg SPEC_CPU_GCC_BINARIES_REPO=${SPEC_CPU_GCC_BINARIES_REPO}"
    fi

    DOCKER_CONTEXT=("." "v119_external")
else
    DOCKER_CONTEXT=${WORKLOAD/*_/}

    case "$PLATFORM" in
    ROME|MILAN|GENOA)
        FIND_OPTIONS="! -name Dockerfile.1.* -o -name Dockerfile.1.aocc-* -o -name Dockerfile.1.gcc-*"
        ;;
    ARMv*)
        FIND_OPTIONS="! -name Dockerfile.1.* -o -name Dockerfile.1.aarch64-*"
        ;;
    *)
        FIND_OPTIONS="! -name Dockerfile.1.* -o -name Dockerfile.1.gcc-* -o -name Dockerfile.1.icc-*"
        ;;
    esac
    FIND_OPTIONS="( $FIND_OPTIONS )"
fi

. "$DIR"/../../script/build.sh

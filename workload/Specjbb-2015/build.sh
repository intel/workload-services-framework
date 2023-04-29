#!/bin/bash -e
SPEC_JBB_VER="${SPEC_JBB_VER:-1.03}"
SPEC_JBB_PKG="${SPEC_JBB_PKG}"

if [ -n "${SPEC_JBB_PKG}" ]; then
    BUILD_OPTIONS="$BUILD_OPTIONS --build-arg SPEC_JBB_VER=${SPEC_JBB_VER} --build-arg SPEC_JBB_PKG=${SPEC_JBB_PKG}"
fi

DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"

echo "Building images for workload $WORKLOAD for platform $PLATFORM"
ARCH=${IMAGEARCH/*\//}

if [[ $IMAGEARCH == linux/arm64 ]]; then
    ARCH="-${ARCH}"
    PACKAGE_ARCH=aarch64
    FIND_OPTIONS="! -name Dockerfile.1.openjdk-1[0-4]* -a -not -name Dockerfile.1.openjdk-[0-9].*"
    BUILD_OPTIONS="$BUILD_OPTIONS --build-arg ARCH=${ARCH} --build-arg PACKAGE_ARCH=${PACKAGE_ARCH}"
    echo "Architecture ${ARCH} with JDK Package for ${PACKAGE_ARCH}"
    DOCKER_CONTEXT=("." "images/openjdk" "images/zulu")
else
    PACKAGE_ARCH=x64
    BUILD_OPTIONS="$BUILD_OPTIONS --build-arg PACKAGE_ARCH=${PACKAGE_ARCH}"
    echo "Architecture ${ARCH} with JDK Package for ${PACKAGE_ARCH}"
    DOCKER_CONTEXT=("." "images/openjdk" "images/zulu")
fi

. "$DIR"/../../script/build.sh

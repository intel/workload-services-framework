#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"

if [[ -z "${STACK}" || "$(awk -F ',' '{print $1}' "${DIR}/versions.txt" | grep "${STACK}" &>/dev/null; echo $?)" != 0 ]]; then
    echo "Please input valid JDK Stack. Check versions.txt" >&2
fi

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
# Split stack into components
IFS="-" read -r vendor version osver <<< "${STACK}"

jdk_url=$(awk -v stack="${STACK}" -F"," '$1 == stack {print $2 }' "${DIR}"/versions.txt)
echo "Stack for JDK $STACK and jdk package $jdk_url jdk version=${version} jdk vendor=${vendor}" 

m4 -DJDK_ARCH=${JDKARCH} -DJDK_VENDOR="${vendor}" -DJDK_VERSION="${version}" -DIMAGESUFFIX="${IMAGESUFFIX}" \
-DJDK_URL="${jdk_url}" "${DIR}"/images/Dockerfile.1.m4 > "${DIR}"/images/Dockerfile.1.ubuntu24."${STACK}"
FIND_OPTIONS="-name Dockerfile.1.ubuntu24.${STACK}" 
 
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IMAGESUFFIX=${IMAGESUFFIX} --build-arg JDK_ARCH=${JDKARCH} --build-arg JDK_VENDOR=${vendor}"
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg JDK_VERSION=${version} --build-arg JDK_URL=${jdk_url}"

DOCKER_CONTEXT=("images")

. "$DIR/../../script/build.sh"

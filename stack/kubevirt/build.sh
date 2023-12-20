#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

REGISTRY=${REGISTRY:-""}

STACK_DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

KUBEVIRT_REPO="https://github.com/kubevirt/kubevirt.git"
KUBEVIRT_VER="v0.58.0"
KUBEVIRT_OUTPUT_PATH="_out/manifests/release"
KUBEVRIT_BUILDER="kubevirt-bazel-server"
KUBEVIRT_PATCH_PATH="$STACK_DIR/patch"

if [[ "$@" != *"--bom"* ]]; then
    # Not for Bom collection, then build the stack

    # check signature to avoid rebuilding multiple times
    signature="$REGISTRY-$RELEASE-$(find "$STACK_DIR" -type f -exec md5sum "{}" \; | sort | md5sum)"

    if [ "$signature" != "$(cat .code-signature.$PLATFORM 2>/dev/null)" ]; then

        export HTTP_PROXY=$http_proxy; export HTTPS_PROXY=$https_proxy ;export NO_PROXY=$no_proxy
        export DOCKER_PREFIX=${REGISTRY%/*}
        export DOCKER_TAG=${RELEASE#*:} 
        export KUBEVIRT_ONLY_USE_TAGS=true
        export IMAGE_PULL_POLICY=Always
        if git version>/dev/null 2>/dev/null; then
            # Git commands should be installed.
            if [ -d ./kubevirt ]; then
                rm -rf ./kubevirt
            fi
            # Backup the JOB_NAME, avoid the conflict with job name of other jobs.
            var_temp=$JOB_NAME
            unset JOB_NAME

            # Build the kubevirt
            git clone -b ${KUBEVIRT_VER} ${KUBEVIRT_REPO} kubevirt && \
            cd kubevirt && EMAIL=builder@localhost git apply --whitespace=fix ${KUBEVIRT_PATCH_PATH}/0001-spdk-vhost-blk-058.patch && \
            make && make push && make manifests && \
            cd ..

            ## cleanup 
            if [ -n "$(docker ps | grep ${KUBEVRIT_BUILDER})" ]; then
                docker stop ${KUBEVRIT_BUILDER}
            fi

            if [ -d ./kubevirt ]; then
                rm -rf ./kubevirt
            fi
            # restore the JOB_NAME
            JOB_NAME=$var_temp
        else
            exit 1
            echo "Failed get kubevirt code, please install git command firstly"
        fi

        echo "$signature" > .code-signature.$PLATFORM
    fi
else
    # Just for Bom collection.
    echo "ARG KUBEVIRT_REPO=${KUBEVIRT_REPO}"
    echo "ARG KUBEVIRT_VER=${KUBEVIRT_VER}"
    echo "ARG RELEASE=${RELEASE}"
fi

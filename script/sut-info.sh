#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

LOGSDIRH="${LOGSDIRH:-$(pwd)}"
CLUSTER_CONFIG_M4="${CLUSTER_CONFIG_M4:-$SOURCEROOT/cluster-config.yaml.m4}"
CLUSTER_CONFIG_J2="${CLUSTER_CONFIG_J2:-$SOURCEROOT/cluster-config.yaml.j2}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$LOGSDIRH/cluster-config.yaml}"
EXPORT_LOGS="${EXPORT_LOGS:-/export-logs}"

(
    cd "$SOURCEROOT" && \
    if [ -r "${CLUSTER_CONFIG_M4%.m4}" ]; then
        cp -f "${CLUSTER_CONFIG_M4%.m4}" "$CLUSTER_CONFIG"
    elif [ -r "$CLUSTER_CONFIG_M4" ]; then
        m4 -Itemplate -I"$PROJECTROOT/template" \
           -DNAMESPACE=$NAMESPACE \
           -DTESTCASE=$TESTCASE \
           -DPLATFORM=$PLATFORM \
           -DIMAGEARCH=$IMAGEARCH \
           -DIMAGESUFFIX=$IMAGESUFFIX \
           -DWORKLOAD=$WORKLOAD \
           -DBACKEND=$BACKEND \
           -DREGISTRY=$REGISTRY \
           -DRELEASE=$RELEASE \
           -DEXPORT_LOGS=$EXPORT_LOGS \
           $RECONFIG_OPTIONS \
           "$CLUSTER_CONFIG_M4" > "$CLUSTER_CONFIG"
    elif [ -r "$CLUSTER_CONFIG_J2" ]; then
        ansible all -i "localhost," -c local -m template \
            -a "src=\"$CLUSTER_CONFIG_J2\" dest=\"$CLUSTER_CONFIG\"" \
            -e NAMESPACE=$NAMESPACE \
            -e TESTCASE=$TESTCASE \
            -e PLATFORM=$PLATFORM \
            -e IMAGEARCH=$IMAGEARCH \
            -e IMAGESUFFIX=$IMAGESUFFIX \
            -e WORKLOAD=$WORKLOAD \
            -e BACKEND=$BACKEND \
            -e REGISTRY=$REGISTRY \
            -e RELEASE=$RELEASE \
            -e EXPORT_LOGS=$EXPORT_LOGS \
            $J2_OPTIONS
    fi
)

if [ -r "$PROJECTROOT/script/$BACKEND/sut-info.sh" ]; then
  . "$PROJECTROOT/script/$BACKEND/sut-info.sh"
fi


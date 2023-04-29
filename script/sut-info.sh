#!/bin/bash -e

LOGSDIRH="${LOGSDIRH:-$(pwd)}"
CLUSTER_CONFIG_M4="${CLUSTER_CONFIG_M4:-$SOURCEROOT/cluster-config.yaml.m4}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$LOGSDIRH/cluster-config.yaml}"
EXPORT_LOGS="${EXPORT_LOGS:-/export-logs}"

# args: yaml
rebuild_config () {
    (cd "$SOURCEROOT" && \
    m4 -Itemplate -I"$PROJECTROOT/template" \
      -DNAMESPACE=$NAMESPACE \
      -DTESTCASE=$TESTCASE \
      -DPLATFORM=$PLATFORM \
      -DIMAGEARCH=$IMAGEARCH \
      -DWORKLOAD=$WORKLOAD \
      -DBACKEND=$BACKEND \
      -DREGISTRY=$REGISTRY \
      -DRELEASE=$RELEASE \
      -DEXPORT_LOGS=$EXPORT_LOGS \
      $RECONFIG_OPTIONS \
      "$@")
}

if [ -r "$CLUSTER_CONFIG_M4" ]; then
    rebuild_config "$CLUSTER_CONFIG_M4" > "$CLUSTER_CONFIG"
fi

if [ -r "$PROJECTROOT/script/$BACKEND/sut-info.sh" ]; then
  . "$PROJECTROOT/script/$BACKEND/sut-info.sh"
fi


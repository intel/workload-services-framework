#!/bin/bash -e

DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
WORKLOAD=${WORKLOAD:-stream}

case $PLATFORM in
ARMv8 | ARMv9)
  echo "Build containers for ARM platforms"
  DOCKER_CONTEXT=("." "arm")
  ;;
MILAN | ROME)
  echo "Build containers for AMD platforms"
  DOCKER_CONTEXT=("." "amd")
  if [[ "$WORKLOAD" =~ "aocc" ]]; then
    echo "Build containers for AMD platforms and aocc version 4 compiler"
    FIND_OPTIONS="-not -name Dockerfile.1.amd"
  else
    echo "Build containers for AMD platforms and aocc version 3 compiler"
    FIND_OPTIONS="-not -name Dockerfile.1.amd-aocc-4"
  fi
  ;;
GENOA)
  echo "Build containers for AMD GENOA platform"
  DOCKER_CONTEXT=("." "amd-zen4")
  ;;
*)
  echo "Build containers for Intel platforms"
  DOCKER_CONTEXT=("." "intel")
  ;;
esac

. "$DIR/../../script/build.sh"

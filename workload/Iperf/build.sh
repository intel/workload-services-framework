#!/bin/bash -e

BUILD_OPTIONS="$BUILD_OPTIONS --build-arg IPERF_VER=${WORKLOAD:5:1}"
FIND_OPTIONS="( ! -name *.m4 $FIND_OPTIONS )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

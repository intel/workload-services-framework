#!/bin/bash -e

CHARMARCH=linux-x86_64
ARCHSETTING=x86_64

BUILD_OPTIONS="$BUILD_OPTIONS  --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"

FIND_OPTIONS="( -name Dockerfile.1.amd64mongodb441.* $FIND_OPTIONS )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh


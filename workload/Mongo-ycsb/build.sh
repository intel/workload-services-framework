#!/bin/bash -e

STACK_DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
STACK="${WORKLOAD#*_}" "$STACK_DIR/../../stack/MongoDB/build.sh" $@

CHARMARCH=linux-x86_64
ARCHSETTING=x86_64

BUILD_OPTIONS="$BUILD_OPTIONS  --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"
FIND_OPTIONS="( ! -name *.m4 $FIND_OPTIONS )"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

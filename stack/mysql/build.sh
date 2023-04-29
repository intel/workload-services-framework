#!/bin/bash -e
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
USECASE=${USECASE:-"base"}

case $PLATFORM in
    ARMv8 | ARMv9 )
        FIND_OPTIONS="( -name Dockerfile.?.mysql.arm $FIND_OPTIONS )"
        ;;
    * )
        FIND_OPTIONS="( -name Dockerfile.?.mysql.${USECASE}* $FIND_OPTIONS )"
        ;;
esac

. "$DIR/../../script/build.sh"

#!/bin/bash -e
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

# extract usecase and mysql version from workload name.
MYSQL_USECASE=$(echo $WORKLOAD | cut -d_ -f4)
STACK="mysql" USECASE=$MYSQL_USECASE "$DIR/../../stack/mysql/build.sh" $@

MYSQL_VER=${WORKLOAD/*mysql/}
# the name of base image from stack follows mysql<version>-<usecase>(-arm64)
MYSQL_BASE_IMAGE="mysql${MYSQL_VER:0:4}-${MYSQL_USECASE}"
if [[ -n $MYSQL_VER ]]; then
    MYSQL_VER_CONCAT="${MYSQL_VER:0:1}.${MYSQL_VER:1:1}.${MYSQL_VER:2:2}"
    BUILD_OPTIONS="$BUILD_OPTIONS --build-arg MYSQL_VER=$MYSQL_VER_CONCAT"
fi

case $PLATFORM in
    MILAN | ROME | GENOA )
        CHARMARCH=linux-x86_64
        ARCHSETTING=x86_64
        ;; 
    * )
        CHARMARCH=linux-x86_64
        ARCHSETTING=x86_64
esac

FIND_OPTIONS="( -name Dockerfile.?.mysql -o -name Dockerfile.?.hammerdb $FIND_OPTIONS)"
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg MYSQL_BASE_IMAGE=${MYSQL_BASE_IMAGE}"

# build aarch64 image
BUILD_OPTIONS="$BUILD_OPTIONS --build-arg CHARMARCH=$CHARMARCH --build-arg ARCHSETTING=$ARCHSETTING"

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. $DIR/../../script/build.sh
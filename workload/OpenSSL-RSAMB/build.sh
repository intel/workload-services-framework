#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"


# build workload images
FIND_OPTIONS="-name *.${WORKLOAD/*_/}"
. "$DIR"/../../script/build.sh

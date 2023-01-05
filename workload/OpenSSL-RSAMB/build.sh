#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

# build dependencies
if [[ "$WORKLOAD" = *_qathw ]]; then
    STACK="qat_setup" "$DIR/../../stack/QAT-Setup/build.sh" $@
fi

# build workload images
FIND_OPTIONS="-name *.${WORKLOAD/*_/}"
. "$DIR"/../../script/build.sh

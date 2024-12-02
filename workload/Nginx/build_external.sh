#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

WORKLOAD=${WORKLOAD:-"nginx_original"}
if [[ "$WORKLOAD" == *_ARMv* ]]; then
    FIND_OPTIONS="( -name *ssl3* -name *.arm )"
elif [[ "$WORKLOAD" == *_qathw* ]]; then
  STACK="qatsw_ssl3_ubuntu_24.04.1" "$DIR/../../stack/QAT/build.sh" $@
  STACK="qathw_ssl3_ubuntu_24.04.1" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( -name *ssl3* -name *.intel ! -name *.qatsw* ! -name *.original* )"
elif [[ "$WORKLOAD" == *_qatsw* ]]; then
  STACK="qatsw_ssl3_ubuntu_24.04.1" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( -name *ssl3* -name *.intel ! -name *.qathw* ! -name *.original* )"
else
  STACK="qatsw_ssl3_ubuntu_24.04.1" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( -name *ssl3* -name *.intel ! -name *.qathw* ! -name *.qatsw* )"
fi

if [[ -e "$DIR/${BACKEND}-config/build.sh" ]]; then
    . "$DIR/${BACKEND}-config/build.sh" $@
fi

echo "FIND_OPTIONS=$FIND_OPTIONS"
. "$DIR/../../script/build.sh"

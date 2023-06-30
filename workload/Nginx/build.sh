#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="qatsw_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@
WORKLOAD=${WORKLOAD:-"nginx_original"}
if [[ "$WORKLOAD" == *_qathw ]]; then
  STACK="qathw_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( ( -name *.intel ! -name *.qatsw* ! -name *.original* ) -o -name *.qathw* )"
elif [[ "$WORKLOAD" == *_qatsw ]]; then 
  FIND_OPTIONS="( ( -name *.intel ! -name *.qathw* ! -name *.original* ) -o -name *.qatsw* )"
else
  FIND_OPTIONS="( -name *.intel ! -name *.qathw* ! -name *.qatsw* )"
fi

echo "FIND_OPTIONS=$FIND_OPTIONS"
. "$DIR/../../script/build.sh"

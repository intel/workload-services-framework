#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

WORKLOAD=${WORKLOAD:-"cdn_nginx_original"}
if [[ "$WORKLOAD" == *_qathw ]]; then
  STACK="qatsw_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@
  STACK="qathw_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( ( -name Dockerfile.* ! -name *.qatsw* ) -o -name *.qathw* )"
elif [[ "$WORKLOAD" == *_qatsw ]]; then 
  STACK="qatsw_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( ( -name Dockerfile.* ! -name *.qathw* ) -o -name *.qatsw* )"
else
  STACK="qatsw_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@
  FIND_OPTIONS="( -name Dockerfile.* ! -name *.qathw* ! -name *.qatsw* )"
fi

echo "FIND_OPTIONS=$FIND_OPTIONS"

. "$DIR"/../../script/build.sh

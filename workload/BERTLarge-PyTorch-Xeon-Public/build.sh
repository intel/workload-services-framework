#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@

WORKLOAD=${WORKLOAD:-bertlarge-pytorch-xeon-public-inference}
FUNCTION=$(echo ${WORKLOAD}|cut -d- -f5)

FIND_OPTIONS="( -name Dockerfile.?.${FUNCTION}-dataset -o -name Dockerfile.?.model -o -name Dockerfile.?.benchmark -o -name Dockerfile.?.${FUNCTION} $FIND_OPTIONS )"

# build PyTorch Workload Base image
. "$DIR"/../../script/build.sh
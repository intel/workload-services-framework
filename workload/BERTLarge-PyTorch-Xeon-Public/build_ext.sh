#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public_24.04" "$DIR"/../../stack/PyTorch-Xeon/build_ext.sh $@

WORKLOAD=${WORKLOAD:-bertlarge-pytorch-xeon-public-inference-24.04}
FUNCTION=$(echo ${WORKLOAD}|cut -d- -f5)

FIND_OPTIONS="( -name Dockerfile.?.${FUNCTION}-dataset_24.04 -o -name Dockerfile.?.model_24.04 -o -name Dockerfile.?.benchmark_24.04 -o -name Dockerfile.?.${FUNCTION}_24.04 $FIND_OPTIONS )"

# build PyTorch Workload Base image
. "$DIR"/../../script/build.sh
#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public_24.04" "$DIR"/../../stack/PyTorch-Xeon/build_ext.sh $@

# build pytorch Workload Base image
WORKLOAD=${WORKLOAD:-distilbert-pytorch-xeon-public}

FIND_OPTIONS="( -name Dockerfile.?.dataset_24.04 -o -name Dockerfile.?.model_24.04 -o -name Dockerfile.?.benchmark_24.04 -o -name Dockerfile.?.intel-public_24.04 $FIND_OPTIONS )"

. "$DIR"/../../script/build.sh

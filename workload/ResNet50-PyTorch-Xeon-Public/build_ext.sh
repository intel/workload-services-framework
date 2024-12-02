#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public_24.04" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@

WORKLOAD=${WORKLOAD:-resnet50_pytorch_xeon_public}

case ${WORKLOAD} in
    * )
        FIND_OPTIONS="( -name Dockerfile.?.inference-dataset_24.04 -o -name Dockerfile.?.model_24.04 -o -name Dockerfile.?.benchmark_24.04 -o -name Dockerfile.?.intel-public-inference_24.04 $FIND_OPTIONS )"
    ;;
esac

. "$DIR"/../../script/build.sh

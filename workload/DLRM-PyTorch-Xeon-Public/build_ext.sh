#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public_24.04" "$DIR"/../../stack/PyTorch-Xeon/build_ext.sh $@

WORKLOAD=${WORKLOAD:-dlrm_pytorch_xeon_public}

FIND_OPTIONS="-name Dockerfile.?.dataset_ext -o"

case ${WORKLOAD} in
    *inference_accuracy* )
        FIND_OPTIONS="( $FIND_OPTIONS -name Dockerfile.?.model_24.04 -o -name Dockerfile.?.benchmark_24.04 -o -name Dockerfile.?.inference.accuracy_24.04 )"
        ;;
    *inference_throughput* )
        FIND_OPTIONS="( $FIND_OPTIONS -name Dockerfile.?.benchmark_24.04 -o -name Dockerfile.?.inference_24.04 )"
        ;;
    * )
        FIND_OPTIONS=$FIND_OPTIONS
        ;;
esac
. "$DIR"/../../script/build.sh

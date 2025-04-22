#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [ ${WORKLOAD##*_} == "2204" ]; then
  STACK="pytorch_xeon_oob" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@
else
  STACK="pytorch_xeon_oob_24.04" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@
fi

BUILD_FILES=(Dockerfile.1.inference_${WORKLOAD##*_})

. $DIR/../../script/build.sh

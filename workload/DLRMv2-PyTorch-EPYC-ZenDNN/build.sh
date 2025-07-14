#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@

STACK="pytorch_xeon_public_24.04" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@

WORKLOAD=${WORKLOAD:-dlrmv2-pytorch-epyc-zendnn}

. $DIR/../../script/build.sh

#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="PyTorch-Xeon" "$DIR"/../../stack/PyTorch-Xeon/build.sh public $@

WORKLOAD=${WORKLOAD:-resnet50_pytorch_xeon_public}

. "$DIR"/../../script/build.sh

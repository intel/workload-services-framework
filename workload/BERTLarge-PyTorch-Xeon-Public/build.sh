#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK=ai_common "$DIR"/../../stack/ai_common/build.sh $@
STACK=PyTorch-Xeon "$DIR"/../../stack/PyTorch-Xeon/build.sh public $@

WORKLOAD=${WORKLOAD:-bertlarge-pytorch-xeon-public}

# build PyTorch Workload Base image
. "$DIR"/../../script/build.sh
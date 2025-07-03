# #!/bin/bash -e
# DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


# WORKLOAD=${WORKLOAD:-llms-pytorch-arm}
# FIND_OPTIONS="( -name Dockerfile.?.arm $FIND_OPTIONS )"

# . "$DIR"/../../script/build.sh


#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK=ai_common "$DIR"/../../stack/ai_common/build.sh $@

. "$DIR"/../../script/build.sh

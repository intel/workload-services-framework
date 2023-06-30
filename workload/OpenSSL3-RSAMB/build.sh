#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

# build dependencies
STACK="${WORKLOAD/*_/}_ssl3_ubuntu" "$DIR/../../stack/QAT/build.sh" $@

# build workload images
FIND_OPTIONS="-name *.${WORKLOAD/*_/}"
. "$DIR"/../../script/build.sh

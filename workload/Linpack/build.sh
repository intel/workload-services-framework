#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

PLATFORM=${PLATFORM:-SPR}

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="linpack_base_intel" "$DIR"/../../stack/Linpack/build.sh $@

. "$DIR/../../script/build.sh"

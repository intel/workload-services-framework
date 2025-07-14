#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
if [[ -e "$DIR/build_int.sh" ]]; then
    . "$DIR"/build_int.sh $@
else 
    . "$DIR"/build_ext.sh $@
fi
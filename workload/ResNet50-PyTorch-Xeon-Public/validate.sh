#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [[ -e "$DIR/validate_ext.sh" ]]; then
    . "$DIR/validate_ext.sh" $@
else 
    . "$DIR"/validate_int.sh $@
fi
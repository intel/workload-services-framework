#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

if [[ -e "$DIR/validate_internal.sh" ]]; then
    . "$DIR/validate_internal.sh" $@
else
   . "$DIR/validate_external.sh" $@
fi

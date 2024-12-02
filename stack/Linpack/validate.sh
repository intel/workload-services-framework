#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-linpack_base_intel_version_check}

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd -P )"
. "$DIR/../../script/overwrite.sh"

JOB_FILTER="job-name=benchmark"

if [ -e "$DIR/validate/validate_${PLATFORM}.sh" ]; then
    . $DIR/validate/validate_${PLATFORM}.sh
fi
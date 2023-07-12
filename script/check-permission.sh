#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

for buildsh in "$DIR"/../workload/*/build.sh "$DIR"/../workload/customer/*/*/build.sh "$DIR"/../stack/*/build.sh; do
    if [ -r "$buildsh" ]; then
        [ ! -x "$buildsh" ] && ls -l "$buildsh" && chmod a+rx "$buildsh"
        validatesh="${buildsh/build.sh/validate.sh}"
        [ -r "$validatesh" ] && [ ! -x "$validatesh" ] && ls -l "$validatesh" && chmod a+rx "$validatesh"
        kpish="${buildsh/build.sh/kpi.sh}"
        [ -r "$kpish" ] && [ ! -x "$kpish" ] && ls -l "$kpish" && chmod a+rx "$kpish"
    fi
done


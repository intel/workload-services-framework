#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

LOGSDIRH="$(pwd)/${CTESTSH_PREFIX}logs-${TESTCASE#test_}"
rm -rf "$LOGSDIRH"
mkdir -p "$LOGSDIRH"
cd "$LOGSDIRH"
flock "$BUILDROOT" -c "echo '$LOGSDIRH' >> '$BUILDROOT/.log_files'"
"$SOURCEROOT"/validate.sh "${@}"


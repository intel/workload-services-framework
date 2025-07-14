#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

LOGSDIRH="${LOGSDIRH:-"$(pwd)/${CTESTSH_PREFIX}logs-${TESTCASE#test_}"}"
LOGSDIRH="${LOGSDIRH/"/${CTESTSH_TESTSET_BUILDROOT##*/}/"//}"
rm -rf "$LOGSDIRH"
mkdir -p "$LOGSDIRH"
cd "$LOGSDIRH"
flock "${BUILDROOT%"/${CTESTSH_TESTSET_BUILDROOT##*/}"}"/.log_files -c "echo '$LOGSDIRH' >> '${BUILDROOT%"${CTESTSH_TESTSET_BUILDROOT##*/}"}'/.log_files"
"$SOURCEROOT"/validate.sh "${@}"


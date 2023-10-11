#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

FIND_OPTIONS="( -name Dockerfile*intel* $FIND_OPTIONS )"

. $DIR/../../script/build.sh
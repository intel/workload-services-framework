#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

FIND_OPTIONS="( -name Dockerfile.2.MKL -o -name Dockerfile.1.intel $FIND_OPTIONS )"

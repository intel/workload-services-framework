#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if ! perf version > /dev/null 2> /dev/null; then
    sudo yum install -y perf
fi

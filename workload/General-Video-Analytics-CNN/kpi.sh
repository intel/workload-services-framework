#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
/kpi No. of VAs/ {
    print "*""No. of VAs : "$6;
}
/kpi pipeline_fps/{
    print $2" : "$4;
}
' */output/results/logs/benchmark_*.log 2>/dev/null || true


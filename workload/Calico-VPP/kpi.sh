#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

while IFS= read -r line; do
    if [[ "$line" == "All Ports RX_L1 Throughput (Gbps):"* ]]; then
        # Primary KPI
        printf '*%s\n' "$line"
    elif [[ "$line" == "All Ports "* ]]; then
        printf '%s\n' "$line"
    elif [[ "$line" == "CalicoVPP"* ]]; then
        printf '%s\n' "$line"
    elif [[ "$line" == "TRex "* ]]; then
        printf '%s\n' "$line"
    fi
done < $(find . -name output.log)
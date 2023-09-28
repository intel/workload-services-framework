#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# h265.log processing
h265_count=0
h265_sum=0

while IFS= read -r line; do
    if [[ $line == *"overall"* ]]; then
        number=$(echo "$line" | grep -oE 'total=[0-9]+\.[0-9]+' | grep -Eo "[0-9]+([.][0-9]+)?")
        echo "$number"
        h265_sum=$(awk "BEGIN{print $h265_sum + $number}")
        ((h265_count++))
    fi
done < "h265.log"

echo "h265 streams: $h265_count"
echo "h265 total fps: $h265_sum"
echo "h265 average fps: $(awk "BEGIN{print $h265_sum / $h265_count}")"

# h264.log processing
h264_count=0
h264_sum=0

while IFS= read -r line; do
    if [[ $line == *"overall"* ]]; then
        number=$(echo "$line" | grep -oE 'total=[0-9]+\.[0-9]+' | grep -Eo "[0-9]+([.][0-9]+)?")
        echo "$number"
        h264_sum=$(awk "BEGIN{print $h264_sum + $number}")
        ((h264_count++))
    fi
done < "h264.log"

echo "h264 streams: $h264_count"
echo "h264 total fps: $h264_sum"
echo "h264 average fps: $(awk "BEGIN{print $h264_sum / $h264_count}")"


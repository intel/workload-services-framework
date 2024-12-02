#!/bin/sh -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This dummy workload calculates the PI sequence. with workload-specific custom scale,return_value and sleep_time params

for i in $(seq $ROI); do
   echo "START-ROI-$i"
   time -p sh -c "echo \"scale=$SCALE; 4*a(1)\" | bc -l; sleep $SLEEP_TIME"
   echo "STOP-ROI-$i"
done

exit ${RETURN_VALUE:-0}


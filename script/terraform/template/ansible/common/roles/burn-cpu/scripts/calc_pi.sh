#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

scale="$1"
timeout="$2"
nthreads="$3"

for i in $(seq ${nthreads:-$(nproc)}); do
  timeout ${timeout}s sh -c "echo 'scale=$scale; 4*a(1)' | bc -l" &
done

wait

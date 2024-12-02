#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import sys

stacks = {}
for line in sys.stdin.readlines():
  if line.startswith("#"): continue
  if line.strip():
    l,_,r = line.rpartition(" ")
    if l not in stacks:
      stacks[l] = 0
    stacks[l] = stacks[l] + int(r)

for k in stacks:
  print(f"{k} {stacks[k]}")


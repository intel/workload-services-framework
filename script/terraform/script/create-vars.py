#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import json
import sys

tfoutput = json.load(sys.stdin)
packer = tfoutput["values"]["outputs"]["packer"]["value"]
for k in packer:
  v = "null" if packer[k] is None else packer[k]
  print("export {}='{}'".format(k.upper(), "{}".format(v).replace("'",'"')))


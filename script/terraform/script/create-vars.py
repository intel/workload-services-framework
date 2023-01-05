#!/usr/bin/env python3

import json
import sys

tfoutput = json.load(sys.stdin)
packer = tfoutput["values"]["outputs"]["packer"]["value"]
for k in packer:
  print("export {}='{}'".format(k.upper(), "{}".format(packer[k]).replace("'",'"')))


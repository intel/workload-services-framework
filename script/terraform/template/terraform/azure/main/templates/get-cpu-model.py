#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import winrm
import sys
import json

query = json.load(sys.stdin)

while True:
  try:
    s = winrm.Session('https://{}:{}/wsman'.format(query["host"], query["port"]),
      auth=(query["user"], query["secret"]),
      transport = 'basic',
      server_cert_validation='ignore')
    r = s.run_ps("Get-WmiObject -Class Win32_Processor -ComputerName . | Select-Object -Property Name")
    break
  except Exception as e:
    sys.stderr.write(str(e))

lines = [line for line in r.std_out.decode('utf-8').split('\r\n') if len(line)>0]
cpu_model = lines[-1] if len(lines)>0 else ""
print(json.dumps({
  "cpu_model": cpu_model
}))

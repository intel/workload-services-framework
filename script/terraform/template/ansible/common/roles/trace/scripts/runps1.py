#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import winrm
import sys
import json
import time
from subprocess import Popen, PIPE

host = sys.argv[1]
inventory_cmd = ["/opt/terraform/script/create-inventory.py", "--list"]
try:
  with Popen(inventory_cmd, stdout=PIPE) as p:
    vm_host = json.load(p.stdout)["_meta"]["hostvars"][host]
except:
  vm_host = {}

cmd = " ".join(sys.argv[2:])
if vm_host:
  for retry in range(5):
    try:
      s = winrm.Session('https://{}:{}/wsman'.format(vm_host["ansible_host"], vm_host["ansible_port"]),
        auth=(vm_host["ansible_user"], vm_host["ansible_password"]),
        transport = vm_host["ansible_winrm_transport"],
        server_cert_validation = vm_host["ansible_winrm_server_cert_validation"]
      )
      r = s.run_ps(cmd)
      break
    except Exception as e:
      sys.stderr.write(str(e))
      time.sleep(5)
else:
  sys.stderr.write(f"{host} not found")
  exit(3)


#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import json
import yaml
import os


def get_winrm_credential(csp):
  try:
    with open(f"/home/.{csp}/config.json") as fd:
      return json.load(fd)["winrm_password"]
  except:
    return ""


def get_all_info(hinfo):
  if hinfo.get("ansible_connection", "ssh") == "winrm":
    if hinfo.get("ansible_winrm_transport", "basic") == "basic":
      if not hinfo.get("ansible_password", ""):
        hinfo["ansible_password"] = get_winrm_credential(hinfo.get("csp","static"))
  return hinfo


inventories = {
  "_meta": {
    "hostvars": {
    }
  }
}

with open("inventory.yaml") as fd:
  for doc in yaml.safe_load_all(fd):
    if doc:
      if "all" in doc:
        if "children" in doc["all"]:
          for g in doc["all"]["children"]:
            if g not in inventories:
              inventories[g] = {
                "hosts": [],
                "vars": {}
              }
            for h in doc["all"]["children"][g].get("hosts",{}):
              hinfo = get_all_info(doc["all"]["children"][g]["hosts"][h])

              if h not in inventories["_meta"]["hostvars"]:
                inventories["_meta"]["hostvars"][h] = doc["all"]["children"][g]["hosts"][h]
              if h not in inventories[g]["hosts"]:
                inventories[g]["hosts"].append(h)

print(json.dumps(inventories,indent=4))

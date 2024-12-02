#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import json
import yaml
import os


def get_credential(config_loc, key, ip):
  if key.endswith("_password"):
    for loc in config_loc:
      try:
        with open(f"/home/.{loc}/config.json") as fd:
          config = json.load(fd)
          try:
            if ip:
              return config["hosts"][ip][key]
          except:
            pass
          if key in config:
            return config[key]
      except:
        pass
  return ""
      

def get_all_info(hinfo, sut):
  config_loc = [sut] if sut else []
  config_loc.append(hinfo.get("csp", "static"))

  if hinfo.get("ansible_connection", "ssh") == "winrm":
    if hinfo.get("ansible_winrm_transport", "basic") == "basic":
      if not hinfo.get("ansible_password", ""):
        hinfo["ansible_password"] = get_credential(config_loc, "winrm_password", hinfo.get("public_ip", ""))
  elif hinfo.get("ansible_connection", "ssh") == "ssh":
      if not hinfo.get("bmc_password", ""):
        hinfo["bmc_password"] = get_credential(config_loc, "bmc_password", hinfo.get("public_ip", ""))
  if hinfo.get("pdu_ip","") != '':
    hinfo["pdu_password"] = get_credential(config_loc, "pdu_password", hinfo.get("pdu_ip", ""))
  return hinfo


inventories = {
  "_meta": {
    "hostvars": {
    }
  }
}

sut = None
with open("workload-config.yaml") as fd:
  for doc in yaml.safe_load_all(fd):
    if doc:
      if "terraform_sut" in doc:
        sut = doc["terraform_sut"]

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
              hinfo = get_all_info(doc["all"]["children"][g]["hosts"][h], sut)

              if h not in inventories["_meta"]["hostvars"]:
                inventories["_meta"]["hostvars"][h] = doc["all"]["children"][g]["hosts"][h]
              if h not in inventories[g]["hosts"]:
                inventories[g]["hosts"].append(h)

print(json.dumps(inventories,indent=4))


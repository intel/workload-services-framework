#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import json
import yaml
import sys
import os
import socket


KUBERNETES_CONFIG = "kubernetes-config.yaml"
CLUSTER_CONFIG = "cluster-config.yaml"
COMPOSE_CONFIG = "compose-config.yaml"
DOCKER_CONFIG = "docker-config.yaml"
CLUSTER_INFO = "cluster-info.json"
INVENTORY = "inventory.yaml"
DEPLOYMENT = "deployment.yaml"
WORKLOAD_CONFIG = "workload-config.yaml"

tfoutput = json.load(sys.stdin)
options = tfoutput["values"]["outputs"]["options"]["value"]

with open(CLUSTER_CONFIG) as fd:
  for doc in yaml.safe_load_all(fd):
    if doc and "terraform" in doc:
      for option1 in doc["terraform"]:
        if option1 not in options:
          options[option1] = doc["terraform"][option1]
        elif isinstance(options[option1], dict):
          tmp = copy.deepcopy(doc["terraform"][option1])
          tmp.update(options[option1])
          options[option1] = tmp

for argv in sys.argv:
  if argv.startswith("--"):
    argv = argv[2:]
    if "=" in argv:
      k, _, v = argv.partition("=")
      options[k.replace('-', '_').split(':')[0]] = v.strip().replace('%20', ' ')
    elif argv.startswith("no"):
      options[argv[2:].replace('-', '_').split(':')[0]] = False
    else:
      options[argv.replace('-', '_').split(':')[0]] = True
instances = tfoutput["values"]["outputs"]["instances"]["value"]
options["wl_logs_dir"] = "/opt/workspace"

with open(INVENTORY) as fd:
  for doc in yaml.safe_load_all(fd):
    if doc and "all" in doc:
      inventories = doc["all"]["children"]

workload_config = {}
with open(WORKLOAD_CONFIG) as fd:
  for doc in yaml.safe_load_all(fd):
    if doc:
      workload_config.update(doc)


def _ExtendOptions(updates):
  tmp = options.copy()
  tmp.update(updates)
  tmp.update({
    "workload_config": workload_config
  })
  return tmp


def _WalkTo(node, name):
  try:
    if name in node:
      return node
    for item1 in node:
      node1 = _WalkTo(node[item1], name)
      if node1:
        return node1
  except Exception:
    return None
  return None


def _AddNodeAffinity(spec, nodes):
  static_nodes = [ n for n in nodes if nodes[n] == "static" ]

  if static_nodes:
    if "affinity" not in spec:
      spec["affinity"] = {}

    if "nodeAffinity" not in spec["affinity"]:
      spec["affinity"]["nodeAffinity"] = {}

    if "requiredDuringSchedulingIgnoredDuringExecution" not in spec["affinity"]["nodeAffinity"]:
      spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"] = {}

    if "nodeSelectorTerms" not in spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]:
      spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]["nodeSelectorTerms"] = []

    spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]["nodeSelectorTerms"].append({
      "matchExpressions": [{
        "key": "kubernetes.io/hostname",
        "operator": "In",
        "values": list(set([ x.split(".")[0] for x in static_nodes ] + [ x for x in static_nodes ])),
      }],
    })


def _IsSUTAccessible(image):
  for reg1 in options.get("sut_accessible_registries",options.get("skopeo_sut_accessible_registries", "")).split(","):
    if reg1 and image.startswith(reg1):
      return True
  return False


def _RegistryEnabled():
  my_ip_list = options["my_ip_list"].split(",")
  for h in inventories["cluster_hosts"]["hosts"]:
    if inventories["cluster_hosts"]["hosts"][h]["private_ip"] in my_ip_list:
      return False
  return str(options.get("k8s_enable_registry", 'True')).lower() == 'true'


def _ModifyImageRef(spec, registry_map):
  for c1 in spec:
    if not _IsSUTAccessible(c1["image"]):
      if registry_map[1] and c1["image"].startswith(registry_map[0]):
        c1["image"] = registry_map[1] + os.path.basename(c1["image"])
        c1["imagePullPolicy"] = "Always"

def _ModifyENVValue(spec):
  if isinstance(spec[0], dict) and 'env' in spec[0]:
    for envs in spec[0]['env']:
      for k, v in envs.items():
        if isinstance(v, str) and '%20' in v:
          envs[k]=v.replace('%20', ' ')


def _UpdateK8sConfig(nodes, registry_map):
  with open(KUBERNETES_CONFIG) as fd:
    docs = [d for d in yaml.safe_load_all(fd) if d]

  modified_docs = []
  for doc in docs:
    modified_docs.append(doc)

    spec_tmp = _WalkTo(doc, "spec")
    if not spec_tmp:
      continue

    spec = _WalkTo(doc, "containers")
    if spec and spec["containers"]:
      _AddNodeAffinity(spec, nodes)
      _ModifyImageRef(spec["containers"], registry_map)

    if spec and spec["containers"]:
      _ModifyENVValue(spec["containers"])

    spec = _WalkTo(doc, "initContainers")
    if spec and spec["initContainers"]:
      _ModifyImageRef(spec["initContainers"], registry_map)

    if spec and spec["initContainers"]:
      _ModifyENVValue(spec["initContainers"])

  modified_filename = KUBERNETES_CONFIG+".mod.yaml"
  with open(modified_filename, "w") as fd:
    yaml.dump_all(modified_docs, fd)
  return modified_filename


# match inventories with Kubernetes nodes
workload_nodes = {}
if os.path.exists(CLUSTER_INFO):
  with open(CLUSTER_INFO) as fd:
    docs = json.load(fd)
    for item1 in docs["items"]:
      for addr1 in item1["status"]["addresses"]:
        if addr1["type"] == "InternalIP":
          private_ip = addr1["address"]
        elif addr1["type"] == "Hostname":
          hostname = addr1["address"]
      for host in inventories["workload_hosts"]["hosts"]:
        if private_ip == socket.gethostbyname(inventories["workload_hosts"]["hosts"][host]["private_ip"]):
          workload_nodes[hostname] = inventories["workload_hosts"]["hosts"][host].get('csp', 'static')


playbooks = [{
  "hosts": "localhost",
  "gather_facts": "false",
  "tasks": [{
    "name": "Breakpoint at RunStage",
    "include_role": {
      "name": "breakpoint",
    },
    "vars": _ExtendOptions({
      "breakpoint": "RunStage",
    })
  }]
}]

# generic ansible
if os.path.exists("/opt/workload/template/ansible/custom/deployment.yaml"):
  playbooks.append({
    "name": "deployment",
    "import_playbook": "./template/ansible/custom/deployment.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": workload_config.get('tunables', {}),
    }),
  })

if (((str(options.get("docker", False)).lower()=='true' or str(options.get("native", False)).lower()=='true') and (os.path.exists(DOCKER_CONFIG) or workload_config.get('docker_image','')!='')) or (str(options.get("compose", False)).lower()=='true' and os.path.exists(COMPOSE_CONFIG))) and str(options.get("kubernetes", False)).lower()=='false':
  playbooks.append({
    "name": "deployment",
    "import_playbook": "./template/ansible/docker/deployment.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": workload_config.get('tunables', {}),
    })
  })

elif os.path.exists(KUBERNETES_CONFIG):
  registry_map = options["wl_registry_map"].split(",")
  if _RegistryEnabled():
    k8s_registry_port = options.get("k8s_registry_port", "30668")
    k8s_registry_ip = inventories["controller"]["hosts"]["controller-0"]["private_ip"] if "controller" in inventories else "127.0.0.1"
    registry_map[1] = options.get("k8s_remote_registry_url", k8s_registry_ip + ":" + k8s_registry_port)
    if not registry_map[1].endswith("/"):
      registry_map[1] = registry_map[1] + "/"

  playbooks.append({
    "name": "deployment",
    "import_playbook": "./template/ansible/kubernetes/deployment.yaml",
    "vars": _ExtendOptions({
      "wl_kubernetes_yaml": _UpdateK8sConfig(workload_nodes, registry_map),
      "wl_registry_map": registry_map,
      "wl_tunables": workload_config.get('tunables', {}),
    }),
  })

if os.path.exists("/opt/workload/kpi.sh"):
  playbooks.append({
    "name": "KPI post-processing",
    "hosts": "localhost",
    "gather_facts": False,
    "become": False,
    "tasks": [{
      "name": "kpi post-processing",
      "include_role": {
        "name": "kpi",
      },
      "vars": _ExtendOptions({
        "wl_tunables": workload_config.get('tunables', {}),
      }),
    }],
  })

with open(DEPLOYMENT, "w") as fd:
  yaml.dump(playbooks, fd)


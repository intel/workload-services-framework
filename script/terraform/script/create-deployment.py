#!/usr/bin/env python3

import json
import yaml
import sys
import os


KUBERNETES_CONFIG = "kubernetes-config.yaml"
CLUSTER_CONFIG = "cluster-config.yaml"
CLUSTER_INFO = "cluster-info.json"
INVENTORY = "inventory.yaml"
DEPLOYMENT = "deployment.yaml"
WORKLOAD_CONFIG = "workload-config.yaml"

tfoutput = json.load(sys.stdin)
options = tfoutput["values"]["outputs"]["options"]["value"]
for argv in sys.argv:
  if argv.startswith("--"):
    argv = argv[2:]
    if "=" in argv:
      k, _, v = argv.partition("=")
      options[k.replace('-', '_')] = v
    elif argv.startswith("no"):
      options[argv[2:].replace('-', '_')] = False
    else:
      options[argv.replace('-', '_')] = True
instances = tfoutput["values"]["outputs"]["instances"]["value"]
options["wl_logs_dir"] = "/opt/workspace"

with open(INVENTORY) as fd:
  for doc in yaml.safe_load_all(fd):
    if doc and "all" in doc:
      inventories = doc["all"]["children"]


def _ExtendOptions(updates):
  tmp = options.copy()
  tmp.update(updates)
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
          "values": list(nodes.keys()),
      }],
  })


def _IsSUTAccessible(image):
  for reg1 in options.get("skopeo_sut_accessible_registries", "").split(","):
    if reg1 and image.startswith(reg1):
      return True
  return False


def _RegistryEnabled():
  my_ip_list = options["my_ip_list"].split(",")
  for h in inventories["cluster_hosts"]["hosts"]:
    if inventories["cluster_hosts"]["hosts"][h]["private_ip"] in my_ip_list:
      return False
  return options.get("k8s_enable_registry", True)


def _ModifyImageRef(spec, registry_map):
  for c1 in spec:
    if not _IsSUTAccessible(c1["image"]):
      if registry_map[1] and c1["image"].startswith(registry_map[0]):
        c1["image"] = registry_map[1] + os.path.basename(c1["image"])


def _UpdateK8sConfig(nodes, registry_map):
  with open(KUBERNETES_CONFIG) as fd:
    docs = [d for d in yaml.safe_load_all(fd) if d]

  modified_docs = []
  for doc in docs:
    modified_docs.append(doc)

    spec = _WalkTo(doc, "containers")
    if spec and spec["containers"]:
      _AddNodeAffinity(spec, nodes)
      _ModifyImageRef(spec["containers"], registry_map)

    spec = _WalkTo(doc, "initContainers")
    if spec and spec["initContainers"]:
      _ModifyImageRef(spec["initContainers"], registry_map)

  modified_filename = KUBERNETES_CONFIG+".mod.yaml"
  with open(modified_filename, "w") as fd:
    yaml.dump_all(modified_docs, fd)
  return modified_filename


def _GetTunables():
  with open(WORKLOAD_CONFIG) as fd:
    tunables = {}
    for doc in yaml.safe_load_all(fd):
      if doc:
        if "tunables" in doc:
          for kv in doc["tunables"].split(";"):
            k, _, v = kv.partition(":")
            tunables[k] = v
    return tunables


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
        if private_ip == inventories["workload_hosts"]["hosts"][host]["private_ip"]:
          workload_nodes[hostname] = 1

playbooks = []
timeout = options.get("wl_timeout", "28800,600").split(",")
if len(timeout)<2:
  timeout.append(timeout[0])
if len(timeout)<3:
  timeout.append(int(timeout[0])/2)

if options.get("wl_docker_image", None):
  playbooks.append({
    "name": "deployment",
    "import_playbook": "./template/ansible/docker/deployment.yaml",
    "vars": _ExtendOptions({
      "wl_timeout": timeout,
    })
  })

elif os.path.exists(KUBERNETES_CONFIG):
  registry_map = options["wl_registry_map"].split(",")
  if _RegistryEnabled():
    k8s_registry_port = options.get("k8s_registry_port", "20668")
    registry_map[1] = inventories["controller"]["hosts"]["controller-0"]["private_ip"] + ":" + k8s_registry_port + "/"
  job_filter = options["wl_job_filter"].split("=")
  if len(job_filter)<2:
    job_filter.append(job_filter[0])

  playbooks.append({
    "name": "deployment",
    "import_playbook": "./template/ansible/kubernetes/deployment.yaml",
    "vars": _ExtendOptions({
      "wl_kubernetes_yaml": _UpdateK8sConfig(workload_nodes, registry_map),
      "wl_timeout": timeout,
      "wl_job_filter": job_filter,
      "wl_registry_map": registry_map,
    }),
  })

# generic ansible
if os.path.exists("/opt/workload/template/ansible/custom/deployment.yaml"):
  playbooks.append({
    "name": "deployment",
    "import_playbook": "./template/ansible/custom/deployment.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": _GetTunables(),
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
      }),
    }],
  })

with open(DEPLOYMENT, "w") as fd:
  yaml.dump(playbooks, fd)


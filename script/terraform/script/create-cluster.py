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
import copy

CLUSTER_CONFIG = "cluster-config.yaml"
KUBERNETES_CONFIG = "kubernetes-config.yaml"
COMPOSE_CONFIG = "compose-config.yaml"
INVENTORY = "inventory.yaml"
CLUSTER = "cluster.yaml"
CLEANUP = "cleanup.yaml"
SSH_CONFIG = "ssh_config_bastion"
WORKLOAD_CONFIG = "workload-config.yaml"

tfoutput = json.load(sys.stdin)
options = tfoutput["values"]["outputs"]["options"]["value"]
for argv in sys.argv:
  if argv.startswith("--"):
    argv = argv[2:]
    if "=" in argv:
      k, _, v = argv.partition("=")
      options[k.replace('-', '_')] = v.strip().replace('%20', ' ')
    elif argv.startswith("no"):
      options[argv[2:].replace('-', '_')] = False
    else:
      options[argv.replace('-', '_')] = True
instances = tfoutput["values"]["outputs"]["instances"]["value"]
kubeadm_options = [ "--pod-network-cidr=10.244.0.0/16" ]
options["wl_logs_dir"] = "/opt/workspace"


def _GetVMGroup(host):
  return instances[host].get("vm_group", "-".join(host.split("-")[:-1]))


inventories = {
  "workload_hosts": {
    "hosts": {},
  },
  "off_cluster_hosts": {
    "hosts": {},
  },
  "cluster_hosts": {
    "hosts": {},
  },
  "trace_hosts": {
    "hosts": {},
  },
}
bastion_hosts = {}
for host in instances:
  if "private_ip" not in instances[host]:
    continue
  vm_group = _GetVMGroup(host)
  if vm_group not in inventories:
    inventories[vm_group]={
      "hosts": {}
    }
  inventories[vm_group]["hosts"][host]=dict(instances[host])
  inventories[vm_group]["hosts"][host].update({
    "ansible_host": instances[host].get("public_ip", instances[host]["private_ip"]),
    "ansible_user": instances[host]["user_name"],
    "ansible_port": instances[host].get("ssh_port", 22),
    "wl_kernel_args": options.get("wl_kernel_args", {}),
  })
  if vm_group == "controller":
    inventories["cluster_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]
  if "bastion_host" in instances[host]:
    if instances[host]["bastion_host"] not in bastion_hosts:
      bastion_hosts[instances[host]["bastion_host"]] = []
    bastion_hosts[instances[host]["bastion_host"]].append(host)
  if "winrm_password" in instances[host]:
    inventories[vm_group]["hosts"][host].update({
      "ansible_connection": "winrm",
      "ansible_password": instances[host]["winrm_password"],
      "ansible_port": instances[host].get("winrm_port", "5986"),
      "ansible_winrm_server_cert_validation": "ignore",
      "ansible_winrm_transport": "basic",
      "ansible_winrm_scheme": "https",
    })

workload_config={}
with open(WORKLOAD_CONFIG) as fd:
  for doc in yaml.safe_load_all(fd):
    if doc:
      workload_config.update(doc)

def _ExtendOptions(updates):
  tmp = options.copy()
  tmp.update(updates)
  return tmp


def _GetNextHost(hosts, n):
  hostnames = list(hosts.keys())
  return hostnames[n % len(hostnames)]


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


def _ScanK8sImages():
  images = {}
  if os.path.exists(KUBERNETES_CONFIG):
    with open(KUBERNETES_CONFIG) as fd:
      for doc in yaml.safe_load_all(fd):
        if doc:
          spec = _WalkTo(doc, "spec")
          if not spec:
            continue
          for c1 in ["containers", "initContainers"]:
            spec = _WalkTo(doc, c1)
            if spec:
              for c2 in spec[c1]:
                if "image" in c2:
                  images[c2["image"]] = 1
  return list(images.keys())


def _ScanDockerImages():
  images = {}

  if options.get("compose", False) and os.path.exists(COMPOSE_CONFIG):
    with open(COMPOSE_CONFIG) as fd:
      for doc in yaml.safe_load_all(fd):
        if doc:
          if "services" in doc:
            for svc in doc["services"]:
              if "image" in doc["services"][svc]:
                images[doc["services"][svc]["image"]] = 1

  if options.get("docker", False) and "docker_image" in workload_config:
    images[workload_config["docker_image"]] = 1

  return list(images.keys())


def _DecodeKernelArgs(line):
  llist = line.split(" ")
  return { llist[k]:llist[k+1] for k in range(0,len(llist)-1,2) }


def _EncodeKernelArgs(args):
  return " ".join([f"{k} {args[k]}" for k in args])


def _IsSUTAccessible(image):
  for reg1 in options.get("skopeo_sut_accessible_registries", "").split(","):
    if reg1 and image.startswith(reg1):
      return True
  return False


def _IsRegistrySecure(image):
  for reg1 in options.get("skopeo_insecure_registries", "").split(","):
    if reg1 and image.startswith(reg1):
      return "false"
  return "true"


def _CreatePerHostCtls(name, ctls):
  for group in ctls:
    for igroup in inventories:
      for host in inventories[igroup]["hosts"]:
        vm_group = _GetVMGroup(host)
        if vm_group == group:
          inventories[igroup]["hosts"][host][name] = ctls[group]


def _List2Dict(alist):
  adict = {}
  for e in alist.split(","):
    k, _, v = e.partition("=")
    adict[k] = v
  return adict


def _RegistryEnabled():
  my_ip_list = options["my_ip_list"].split(",")
  for h in inventories["cluster_hosts"]["hosts"]:
    if inventories["cluster_hosts"]["hosts"][h]["private_ip"] in my_ip_list:
      return False
  return str(options.get("k8s_enable_registry", 'True')).lower() == 'true'


nidx = {}
sysctls = {}
sysfs = {}
bios = {}
with open(CLUSTER_CONFIG) as fd:
  for doc in yaml.safe_load_all(fd):
    if doc and "cluster" in doc:
      for i,c in enumerate(doc["cluster"]):
        vm_group = c["vm_group"] if "vm_group" in c else "worker"
        if vm_group not in inventories:
          raise Exception(f"Unknown vm_group {vm_group} in {inventories}")
        if vm_group not in nidx:
          nidx[vm_group] = 0
        host = _GetNextHost(inventories[vm_group]["hosts"], nidx[vm_group])

        if vm_group != "controller":
          if c.get("off_cluster", False):
            inventories["off_cluster_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]
          else:
            inventories["workload_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]
            inventories["cluster_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]

        if c.get("traceable", vm_group != "controller"):
          inventories["trace_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]

        if "k8s_node_labels" not in inventories[vm_group]["hosts"][host]:
            inventories[vm_group]["hosts"][host]["k8s_node_labels"] = []

        vm_group_label = f"VM-GROUP={vm_group}"
        if vm_group_label not in inventories[vm_group]["hosts"][host]["k8s_node_labels"]:
          inventories[vm_group]["hosts"][host]["k8s_node_labels"].append(vm_group_label)
        nidx[vm_group] = nidx[vm_group] + 1

        if c["labels"]:
          for label in c["labels"]:
            label_str = f"{label}=yes"
            if label_str not in inventories[vm_group]["hosts"][host]["k8s_node_labels"]:
              inventories[vm_group]["hosts"][host]["k8s_node_labels"].append(label_str)

        if "sysctls" in c:
          if vm_group not in sysctls:
            sysctls[vm_group] = {}
          sysctls[vm_group].update(c["sysctls"])

        if "sysfs" in c:
          if vm_group not in sysfs:
            sysfs[vm_group] = {}
          sysfs[vm_group].update(c["sysfs"])

        if "bios" in c:
          if vm_group not in bios:
            bios[vm_group] = {}
          bios[vm_group].update(c["bios"])

    if doc and "terraform" in doc:
      for option1 in doc["terraform"]:
        if option1 not in options:
          options[option1] = doc["terraform"][option1]
        elif isinstance(options[option1], dict):
          tmp = copy.deepcopy(doc["terraform"][option1])
          tmp.update(options[option1])
          options[option1] = tmp


_CreatePerHostCtls("wl_sysctls", sysctls)
_CreatePerHostCtls("wl_sysfs", sysfs)
_CreatePerHostCtls("wl_bios", bios)

playbooks = [{
  "name": "startup sequence",
  "import_playbook": "./template/ansible/common/startup.yaml",
  "vars": _ExtendOptions({
    p: _List2Dict(options[p]) for p in ["wl_default_sysctls", "wl_default_sysfs"] if p in options
  })
}]

if ((options.get("docker", False) or options.get("native", False)) and ("docker_image" in workload_config)) or (options.get("compose", False) and os.path.exists(COMPOSE_CONFIG)):
  playbooks.append({
    "name": "docker installation",
    "import_playbook": "./template/ansible/docker/installation.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": workload_config.get('tunables', {}),
    })
  })
  playbooks.append({
    "name": "transfer image",
    "import_playbook": "./template/ansible/common/image_to_daemon.yaml",
    "vars": _ExtendOptions({
      "wl_docker_images": {
        im: _IsRegistrySecure(im) for im in _ScanDockerImages() if not _IsSUTAccessible(im)
      },
    })
  })

elif os.path.exists(KUBERNETES_CONFIG) or options.get("k8s_install", False):
  k8s_registry_port = options.get("k8s_registry_port", "20668")
  k8s_registry_ip = inventories["controller"]["hosts"]["controller-0"]["private_ip"] if "controller" in inventories else "127.0.0.1"

  playbooks.append({
    "name": f"k8s installation",
    "import_playbook": "./template/ansible/kubernetes/installation.yaml",
    "vars": _ExtendOptions({
      "k8s_registry_port": k8s_registry_port,
      "k8s_registry_ip": k8s_registry_ip,
      "wl_tunables": workload_config.get('tunables', {}),
    })
  })

  if _RegistryEnabled():
    images = options["wl_docker_images"].split(",") if "wl_docker_images" in options else _ScanK8sImages()
    playbooks.append({
      "name": "transfer image",
      "import_playbook": "./template/ansible/common/image_to_registry.yaml",
      "vars": _ExtendOptions({
        "wl_docker_images": {
          im: _IsRegistrySecure(im) for im in images if not _IsSUTAccessible(im)
        },
        "k8s_remote_registry_url": options.get("k8s_remote_registry_url", k8s_registry_ip + ":" + k8s_registry_port),
      })
    })

if os.path.exists("/opt/workload/template/ansible/custom/installation.yaml"):
  playbooks.append({
    "name": "create cluster",
    "import_playbook": "./template/ansible/custom/installation.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": workload_config.get('tunables', {}),
    })
  })

if inventories["trace_hosts"]["hosts"]:
  playbooks.append({
    "name": "Install traces",
    "import_playbook": "./template/ansible/common/trace.yaml",
    "vars": _ExtendOptions({
    })
  })

if options.get("svrinfo", True):
  playbooks.append({
    "name": "Invoke svrinfo",
    "import_playbook": "./template/ansible/common/svrinfo.yaml",
    "vars": _ExtendOptions({
    })
  })
  
if options.get("msrinfo", False):
  playbooks.append({
    "name": "Invoke msrinfo",
    "import_playbook": "./template/ansible/common/msrinfo.yaml",
    "vars": _ExtendOptions({
    })
  })

with open(CLUSTER, "w") as fd:
  yaml.dump(playbooks, fd)

with open(CLEANUP, "w") as fd:
  playbooks = [{
    "hosts": "localhost",
    "gather_facts": "false",
    "tasks": [{
      "name": "Breakpoint at CleanupStage",
      "include_role": {
        "name": "breakpoint",
      },
      "vars": _ExtendOptions({
        "breakpoint": "CleanupStage",
      })
    }]
  }]

  if ((options.get("docker", False) or options.get("native", False)) and ("docker_image" in workload_config)) or (options.get("compose", False) and os.path.exists(COMPOSE_CONFIG)):
    playbooks.append({
      "name": "Docker cleanup sequence",
      "import_playbook": "./template/ansible/docker/cleanup.yaml",
      "vars": _ExtendOptions({
        "wl_tunables": workload_config.get('tunables', {}),
      }),
    })

  # k8s cleanup
  if os.path.exists(KUBERNETES_CONFIG) or options.get("k8s_install", False):
    playbooks.append({
      "name": "Kubernetes cleanup sequence",
      "import_playbook": "./template/ansible/kubernetes/cleanup.yaml",
      "vars": _ExtendOptions({
        "wl_tunables": workload_config.get('tunables', {}),
      }),
    })

  # custom cleanup
  if os.path.exists("/opt/workload/template/ansible/custom/cleanup.yaml"):
    playbooks.append({
      "name": "custom cleanup sequence",
      "import_playbook": "./template/ansible/custom/cleanup.yaml",
      "vars": _ExtendOptions({
        "wl_tunables": workload_config.get('tunables', {}),
      }),
    })

  # default cleanup
  playbooks.append({
    "name": "default cleanup sequence",
    "import_playbook": "./template/ansible/common/cleanup.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": workload_config.get('tunables', {}),
    }),
  })

  yaml.dump(playbooks, fd)

with open(INVENTORY, "w") as fd:
  inventory_update = options.get("ansible_inventory", {})
  for group in inventory_update:
    if "hosts" in inventory_update[group]:
      if group not in inventories:
        inventories[group] = {"hosts": {}}
      inventories[group]["hosts"].update(inventories_update[group]["hosts"])
  yaml.dump({
    "all": {
      "children": inventories
    }
  }, fd)

if bastion_hosts:
  with open(SSH_CONFIG, "w") as fd:
    for bh in bastion_hosts:
      for ph in bastion_hosts[bh]:
        fd.write("Host {} {}\n".format(ph, instances[ph]["private_ip"]))
        fd.write("  Hostname {}\n".format(instances[ph]["private_ip"]))
        fd.write("  User {}\n".format(instances[ph]["user_name"]))
        fd.write("  ProxyCommand ssh -i {} {}@{} -W %h:%p\n".format(os.path.abspath("ssh_access.key"), instances[bh]["user_name"], instances[bh]["public_ip"]))


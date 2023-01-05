#!/usr/bin/env python3

import json
import yaml
import sys
import os

CLUSTER_CONFIG = "cluster-config.yaml"
KUBERNETES_CONFIG = "kubernetes-config.yaml"
INVENTORY = "inventory.yaml"
CLUSTER = "cluster.yaml"
CLEANUP = "cleanup.yaml"
SSH_CONFIG = "ssh_config"
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
kubeadm_options = [ "--pod-network-cidr=10.244.0.0/16" ]
options["wl_logs_dir"] = "/opt/workspace"


def _GetVMGroup(host):
  return instances[host].get("vm_group", "-".join(host.split("-")[:-1]))


inventories = {
  "workload_hosts": {
    "hosts": {},
  },
  "cluster_hosts": {
    "hosts": {},
  },
  "trace_hosts": {
    "hosts": {},
  },
}
non_controller_groups = {}
bastion_hosts = {}
for host in instances:
  vm_group = _GetVMGroup(host)
  if vm_group not in inventories:
    inventories[vm_group]={
      "hosts": {}
    }
  inventories[vm_group]["hosts"][host]=dict(instances[host])
  inventories[vm_group]["hosts"][host].update({
    "ansible_host": instances[host].get("public_ip", instances[host]["private_ip"]),
    "ansible_user": instances[host]["user_name"],
    "wl_kernel_args": options.get("wl_kernel_args", {}),
  })
  if vm_group == "controller":
    inventories["cluster_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]
  else:
    non_controller_groups[vm_group] = 1
  if "bastion_host" in instances[host]:
    if instances[host]["bastion_host"] not in bastion_hosts:
      bastion_hosts[instances[host]["bastion_host"]] = []
    bastion_hosts[instances[host]["bastion_host"]].append(host)


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


def _ScanImages():
  images = {}
  with open(KUBERNETES_CONFIG) as fd:
    for doc in yaml.safe_load_all(fd):
      if doc:
        for c1 in ["containers", "initContainers"]:
          spec = _WalkTo(doc, c1)
          if spec:
            for c2 in spec[c1]:
              if "image" in c2:
                images[c2["image"]] = 1
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
    if group in non_controller_groups:
      for host in inventories["workload_hosts"]["hosts"]:
        vm_group = _GetVMGroup(host)
        if vm_group == group:
          inventories["workload_hosts"]["hosts"][host][name] = ctls[group]


def _SetHugePageKernelArgs(kernel_args, hugepagesz, hugepages):
  sz = f"hugepagesz={hugepagesz}"
  if sz in kernel_args:
    hugepages1 = int(kernel_args[sz].split("=")[-1])
    if hugepages1 > hugepages:
      hugepages = hugepages1
  kernel_args[sz] = f'{sz} hugepages={hugepages}'


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
  return options.get("k8s_enable_registry", True)


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


nidx = {}
sysctls = {}
sysfs = {}
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

        inventories["workload_hosts"]["hosts"][host] = inventories[vm_group]["hosts"][host]

        if c.get("traceable", vm_group == "worker"):
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
            
            if "HAS-SETUP-HUGEPAGE-" in label:
              req = label.split("-")[-2:]
              hugepagesz = req[0].replace("B", "")
              hugepages = int(req[1])
              _SetHugePageKernelArgs(inventories[vm_group]["hosts"][host]["wl_kernel_args"], hugepagesz, hugepages)
              
        if "sysctls" in c:
          if vm_group not in sysctls:
            sysctls[vm_group] = {}
          sysctls[vm_group].update(c["sysctls"])

        if "sysfs" in c:
          if vm_group not in sysfs:
            sysfs[vm_group] = {}
          sysfs[vm_group].update(c["sysfs"])

    if doc and "terraform" in doc:
      for option1 in doc["terraform"]:
        if option1 not in options:
          options[option1] = doc["terraform"][option1]

for host1 in inventories["workload_hosts"]["hosts"]:
  vm_group = _GetVMGroup(host1)
  for host2 in inventories[vm_group]["hosts"]:
    inventories["cluster_hosts"]["hosts"][host2] = inventories[vm_group]["hosts"][host2]

_CreatePerHostCtls("wl_sysctls", sysctls)
_CreatePerHostCtls("wl_sysfs", sysfs)

playbooks = [{
  "name": "startup sequence",
  "import_playbook": "./template/ansible/common/startup.yaml",
  "vars": _ExtendOptions({
    p: _List2Dict(options[p]) for p in ["wl_default_sysctls", "wl_default_sysfs"] if p in options
  })
}]

if options.get("wl_docker_image", None):
  playbooks.append({
    "name": "docker installation",
    "import_playbook": "./template/ansible/docker/installation.yaml",
    "vars": _ExtendOptions({
    })
  })
  if not _IsSUTAccessible(options["wl_docker_image"]):
    playbooks.append({
      "name": "transfer image",
      "import_playbook": "./template/ansible/common/image_to_daemon.yaml",
      "vars": _ExtendOptions({
        "wl_docker_images": {
          options["wl_docker_image"]: _IsRegistrySecure(options["wl_docker_image"]),
        },
      })
    })
  if options.get("docker_auth_reuse", False):
    playbooks.append({
      "name": "Docker Auth",
      "import_playbook": "./template/ansible/common/docker_auth.yaml",
      "vars": _ExtendOptions({
      })
    })

elif os.path.exists(KUBERNETES_CONFIG):
  k8s_registry_port = options.get("k8s_registry_port", "20668")

  playbooks.append({
    "name": f"k8s installation",
    "import_playbook": "./template/ansible/kubernetes/installation.yaml",
    "vars": _ExtendOptions({
      "k8s_registry_port": k8s_registry_port,
      "k8s_registry_ip": inventories["controller"]["hosts"]["controller-0"]["private_ip"],
    })
  })

  if _RegistryEnabled():
    images = _ScanImages()
    playbooks.append({
      "name": "transfer image",
      "import_playbook": "./template/ansible/common/image_to_registry.yaml",
      "vars": _ExtendOptions({
        "wl_docker_images": { 
          im: _IsRegistrySecure(im) for im in images if not _IsSUTAccessible(im)
        },
        "k8s_remote_registry_url": inventories["controller"]["hosts"]["controller-0"]["private_ip"]+":" + k8s_registry_port,
      })
    })
    if options.get("docker_auth_reuse", False):
      playbooks.append({
        "name": "Docker Auth",
        "import_playbook": "./template/ansible/common/docker_auth.yaml",
        "vars": _ExtendOptions({
          "wl_workerlist": "controller-0",
        })
      })

if os.path.exists("/opt/workload/template/ansible/custom/installation.yaml"):
  playbooks.append({
    "name": "create cluster",
    "import_playbook": "./template/ansible/custom/installation.yaml",
    "vars": _ExtendOptions({
      "wl_tunables": _GetTunables(),
    })
  })

if options.get("svrinfo", True):
  playbooks.append({
    "name": "Invoke svrinfo",
    "import_playbook": "./template/ansible/common/svrinfo.yaml",
    "vars": _ExtendOptions({
    })
  })
  
with open(CLUSTER, "w") as fd:
  yaml.dump(playbooks, fd)

with open(CLEANUP, "w") as fd:
  playbooks = []

  # custom cleanup
  if os.path.exists("/opt/workload/template/ansible/custom/cleanup.yaml"):
    playbooks.append({
      "name": "custom cleanup",
      "import_playbook": "./template/ansible/custom/cleanup.yaml",
      "vars": _ExtendOptions({
        "wl_tunables": _GetTunables(),
      })
    })
  # k8s cleanup
  if os.path.exists("/opt/workload/template/ansible/kubernetes/cleanup.yaml"):
    playbooks.append({
      "name": "default cleanup sequence",
      "import_playbook": "./template/ansible/kubernetes/cleanup.yaml",
      "vars": _ExtendOptions({
      }),
    })
  # common cleanup
  playbooks.append({
    "name": "default cleanup sequence",
    "import_playbook": "./template/ansible/common/cleanup.yaml",
    "vars": _ExtendOptions({
    }),
  })
  yaml.dump(playbooks, fd)

with open(INVENTORY, "w") as fd:
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


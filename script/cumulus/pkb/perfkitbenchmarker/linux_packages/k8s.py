from absl import flags
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import os_types
from perfkitbenchmarker.linux_packages import docker_ce
from yaml import safe_load_all, dump_all
import logging
import posixpath
import uuid
import os

FLAGS = flags.FLAGS
flags.DEFINE_string("k8s_repo_key_url", "https://packages.cloud.google.com/apt/doc/apt-key.gpg",
                    "Specify the installation repo GPG key url")
flags.DEFINE_string("k8s_repo_url", "http://apt.kubernetes.io/",
                    "Specify the installation repo url")
flags.DEFINE_string("k8s_version", "1.21",
                    "Specify the installation repo url")
flags.DEFINE_string("k8s_nfd_version", "0.10.1",
                    "Specify the node feature discovery version")
flags.DEFINE_boolean("k8s_kubevirt", False,
                     "Specify whether to install kubevirt")
flags.DEFINE_string("k8s_kubevirt_version", "v0.55.0",
                    "Specify the kubevert version")
flags.DEFINE_list("k8s_kubeadm_options", [],
                    "Specify the kubeadm options")
flags.DEFINE_list("k8s_nfd_scripts", [],
                  "Specify any extra node feature discovery scripts")
flags.DEFINE_list("k8s_image_mirrors", [],
                  "Specify docker image mirrors")
flags.DEFINE_enum("k8s_cni", "flannel",
                  ["flannel", "calico"],
                  "Specify the CNI")
flags.DEFINE_string("k8s_flannel_version", "v0.18.1",
                    "Specify the flannel CNI version")
flags.DEFINE_string("k8s_calico_version", "v3.23",
                    "Specify the calico CNI version")
flags.DEFINE_string("k8s_cni_options", "",
                    "Specify the CNI options")


NFD_SOURCE_D = "/etc/kubernetes/node-feature-discovery/source.d"
REGISTRY_CERTS_DIR = "registry-certs"
REGISTRY_YAML = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  labels:
    app: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      volumes:
      - name: cert
        secret:
          secretName: registry-cert
      containers:
        - image: registry:2
          name: registry
          imagePullPolicy: IfNotPresent
          env:
          - name: REGISTRY_HTTP_TLS_CERTIFICATE
            value: "/certs/tls.crt"
          - name: REGISTRY_HTTP_TLS_KEY
            value: "/certs/tls.key"
          ports:
            - containerPort: 5000
          volumeMounts:
          - name: cert
            mountPath: /certs
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
---
apiVersion: v1
kind: Service
metadata:
  name: registry-service
  labels:
    app: registry-service
spec:
  ports:
    - port: {HOSTPORT}
      targetPort: 5000
  externalIPs:
    - "{HOSTIP}"
  selector:
    app: registry
""".replace("\n", "\\n")
POD_NETWORK_CIDR = "10.244.0.0/16"


def YumInstall(vm):
  raise Exception("Not Implemented")


def AptInstall(vm):
  vm.InstallPackages(f'apt-transport-https ca-certificates curl')
  vm.RemoteCommand(f'curl {FLAGS.k8s_repo_key_url} | sudo apt-key add -')
  vm.RemoteCommand(f"bash -c 'sudo -E add-apt-repository \"deb [arch=$(dpkg --print-architecture)] {FLAGS.k8s_repo_url} kubernetes-xenial main\"'")
  vm.AptUpdate()
  version, _ = vm.RemoteCommand(f"sudo apt-cache madison kubelet | grep {FLAGS.k8s_version} | cut -f2 -d'|' | tr -d ' ' | sort -V -r | head -n 1")
  version = version.strip()
  vm.InstallPackages(f'kubeadm={version} kubelet={version} kubectl={version}')


def _InstallNFDScripts(vm):
  for script1 in FLAGS.k8s_nfd_scripts:
    basename = os.path.basename(script1)
    remote_file = posixpath.join(INSTALL_DIR, basename)
    vm.RemoteCopy(script1, remote_file)
    vm.RemoteCommand(f'sudo mv -f {remote_file} {NFD_SOURCE_D}')
  vm.RemoteCommand(f'sudo chmod -R a+rx {NFD_SOURCE_D}')
  vm.RemoteCommand('sudo systemctl restart kubelet')


@vm_util.Retry()
def _RetagImage(vm, image, image_retag):
  if docker_ce.IsDocker(vm):
    vm.RemoteCommand(f"sudo -E docker pull {image}")
    vm.RemoteCommand(f"sudo -E docker tag  {image} {image_retag}")
  else:
    vm.RemoteCommand(f"sudo ctr -n k8s.io i pull {image}")
    vm.RemoteCommand(f"sudo ctr -n k8s.io i tag  {image} {image_retag}")


def _PrepareSystem(vm):
  vm.RemoteCommand("sudo systemctl stop named", ignore_failure=True)
  vm.RemoteCommand("sudo systemctl disable named", ignore_failure=True)

  vm.RemoteCommand("sudo swapoff -a")
  vm.RemoteCommand("sudo sed -ri 's/.*swap.*/#&/' /etc/fstab")

  vm.RemoteCommand("sudo modprobe overlay")
  vm.RemoteCommand("sudo modprobe br_netfilter")
  vm.RemoteCommand("printf 'overlay\\nbr_netfilter\\n' | sudo tee /etc/modules-load.d/k8s.conf")

  vm.RemoteCommand("printf 'net.bridge.bridge-nf-call-ip6tables=1\\nnet.bridge.bridge-nf-call-iptables=1\\nnet.ipv4.ip_forward=1\\nnet.netfilter.nf_conntrack_max=1000000' | sudo tee /etc/sysctl.d/k8s.conf")
  vm.RemoteCommand("sudo sysctl --system")

  version = FLAGS.k8s_version.split(".")
  if int(version[0]) <= 1 and int(version[1]) < 24:
    vm.Install("docker_ce")
  else:
    vm.Install("containerd")

  for i in range(0,len(FLAGS.k8s_image_mirrors),2):
    _RetagImage(vm, FLAGS.k8s_image_mirrors[i], FLAGS.k8s_image_mirrors[i+1])

  vm.Install("k8s")


def _SetCNIOptions():
  if FLAGS.k8s_cni == "flannel":
    FLAGS.k8s_kubeadm_options.append(f"--pod-network-cidr={POD_NETWORK_CIDR}")
  elif FLAGS.k8s_cni == "calico":
    FLAGS.k8s_kubeadm_options.append(f"--pod-network-cidr={POD_NETWORK_CIDR}")
 

def _InstallCNI(vm):
  if FLAGS.k8s_cni == "flannel":
    vm.RemoteCommand(f'kubectl create -f https://raw.githubusercontent.com/flannel-io/flannel/{FLAGS.k8s_flannel_version}/Documentation/kube-flannel.yml')

  elif FLAGS.k8s_cni == "calico":
    if "vxlan" in FLAGS.k8s_cni_options:
      manifest = f"https://projectcalico.docs.tigera.io/archive/{FLAGS.k8s_calico_version}/manifests/calico-vxlan.yaml"
      manifest_mod = "-e \"/CALICO_IPV[4|6]POOL_VXLAN/{n;s|\\\"CrossSubnet\\\"|\\\"Always\\\"|}\""
    else:
      manifest = f"https://projectcalico.docs.tigera.io/archive/{FLAGS.k8s_calico_version}/manifests/calico.yaml"
      manifest_mod = ""

    vm.RemoteCommand(f"bash -c 'kubectl apply -f <(curl -o - {manifest} | sed -e \"s|^\\(\\s*\\)env:\\s*$|\\1env:\\n\\1  - name: CALICO_IPV4POOL_CIDR\\n\\1    value: \\\"{POD_NETWORK_CIDR}\\\"\\n\\1  - name: IP_AUTODETECTION_METHOD\\n\\1    value: \\\"can-reach={vm.internal_ip}\\\"|\" {manifest_mod})'")

    _RobustRemoteCommand(vm, "kubectl wait --namespace=kube-system pod --for=condition=ready -l k8s-app=calico-node")
  else:
    raise Exception(f"Kubernetes: Unsupported CNI {FLAGS.k8s_cni}")


def _InstallNFD(vm, all_vms):
  _RobustRemoteCommand(vm, f"kubectl apply -k 'https://github.com/kubernetes-sigs/node-feature-discovery/deployment/overlays/default?ref=v{FLAGS.k8s_nfd_version}'")
  _RobustRemoteCommand(vm, "kubectl --namespace=node-feature-discovery wait pod --for=condition=ready -l app=nfd-worker")
  if FLAGS.k8s_nfd_scripts:
    vm_util.RunThreaded(lambda vm1: _InstallNFDScripts(vm1), all_vms)


def _InstallKubeVirt(vm):
  if FLAGS.k8s_kubevirt:
    vm.RemoteCommand(f"kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/{FLAGS.k8s_kubevirt_version}/kubevirt-operator.yaml")
    vm.RemoteCommand(f"kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/{FLAGS.k8s_kubevirt_version}/kubevirt-cr.yaml")
    _RobustRemoteCommand(vm, "kubectl -n kubevirt wait kv kubevirt --for condition=Available")


def _UpdateKubeadmConfigFile():
  cluster_config = {
    "apiVersion": "kubeadm.k8s.io/v1beta2",
    "kind": "ClusterConfiguration",
    "networking": {},
  }
  config_file = None
  options = []
  for option1 in FLAGS.k8s_kubeadm_options:
    if option1.startswith("--pod-network-cidr="):
      _, _, cluster_config["networking"]["podSubnet"] = option1.partition("=")
    elif option1.startswith("--image-repository="):
      _, _, cluster_config["imageRepository"] = option1.partition("=")
    elif option1.startswith("--config="):
      _, _, config_file = option1.partition("=")
    else:
      options.append(option1)

  if config_file:
    docs = []
    with open(config_file, "r") as fd:
      cluster_config_doc = False
      for doc1 in safe_load_all(fd):
        if doc1 and "kind" in doc1:
          if doc1["kind"] == "ClusterConfiguration":
            doc1.update(cluster_config)
            cluster_config_doc = True
          docs.append(doc1)
      if not cluster_config_doc:
        docs.append(cluster_config)

    config_yaml = dump_all(docs).replace("\n","\\n").replace('"','\\"')
    options.append("--config=<(printf \"{}\")".format(config_yaml))
    FLAGS.k8s_kubeadm_options = options


def CreateCluster(vm, workers, taint=True):
  all_vms = list(set([vm] + workers))
  vm_util.RunThreaded(lambda vm1: _PrepareSystem(vm1), all_vms)

  _SetCNIOptions()

  _UpdateKubeadmConfigFile()
  vm.RemoteCommand("sudo bash -c 'kubeadm init "+ ' '.join(FLAGS.k8s_kubeadm_options) + "'")
  vm.RemoteCommand('mkdir -p $HOME/.kube')
  vm.RemoteCommand('sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config')
  vm.RemoteCommand("bash -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'")

  cmd, _ = vm.RemoteCommand('sudo kubeadm token create --print-join-command')
  if not cmd.startswith("kubeadm join "):
    raise Exception(f"Invalid kubeadm command: {cmd}")
  vm_util.RunThreaded(lambda vm1: _RobustRemoteCommand(vm1, f'sudo {cmd}'), workers)

  _InstallCNI(vm)
  _RobustRemoteCommand(vm, "kubectl --namespace=kube-system wait pod --all --for=condition=ready")

  _InstallNFD(vm, all_vms)
  _InstallKubeVirt(vm)

  if not taint:
    vm.RemoteCommand(f'kubectl taint node --all --overwrite node-role.kubernetes.io/master-')
    vm.RemoteCommand(f'kubectl taint node --all --overwrite node-role.kubernetes.io/control-plane-')
    

def _OpenSSLConf(vm):
  if vm.BASE_OS_TYPE == os_types.DEBIAN:
    return "/etc/ssl/openssl.cnf"
  if vm.BASE_OS_TYPE == os_types.RHEL:
    return "/etc/pki/tls/openssl.conf"
  raise Exception(f"{vm.BASE_OS_TYPE} Not Supported")
  

def _CopyCertsToWorker(vm, certs_dir):
  vm.RemoteCommand(f"mkdir -p {certs_dir}")
  vm.PushFile(f"{certs_dir}/client.cert", f"{certs_dir}/client.cert")

  if vm.BASE_OS_TYPE == os_types.DEBIAN:
    vm.RemoteCommand(f"sudo cp -f {certs_dir}/client.cert /usr/local/share/ca-certificates/registry.crt")
    vm.RemoteCommand("sudo update-ca-certificates")
  elif vm.BASE_OS_TYPE == os_types.RHEL:
    vm.RemoteCommand(f"sudo cp -f {certs_dir}/client.cert /etc/pki/ca-trust/source/anchors/registry.crt")
    vm.RemoteCommand("sudo update-ca-trust")
  else:
    raise Exception(f"{vm.BASE_OS_TYPE} not supported")

  if docker_ce.IsDocker(vm):
    vm.RemoteCommand("sudo systemctl restart docker")
  else:
    vm.RemoteCommand("sudo systemctl restart containerd")
  vm.RemoteCommand("sudo systemctl restart kubelet")


def CreateRegistry(vm, workers, port=5000):
  registry_url = f"{vm.internal_ip}:{port}"
  certs_dir = vm_util.PrependTempDir(f"{REGISTRY_CERTS_DIR}/{registry_url}")

  vm_util.IssueCommand(["mkdir", "-p", certs_dir])
  vm_util.IssueCommand(["openssl", "req", "-newkey", "rsa:4096", "-nodes", "-sha256", "-keyout", f"{certs_dir}/client.key", "--addext", f"subjectAltName = IP:{vm.internal_ip}", "-x509", "-days", "365", "-out", f"{certs_dir}/client.cert", "-subj", f"/CN={vm.internal_ip}"])
  vm_util.IssueCommand(["chmod", "400", f"{certs_dir}/client.key"])
  #vm_util.IssueCommand(["cp", "-f", f"{certs_dir}/client.cert", f"{certs_dir}/ca.crt"])

  vm_util.RunThreaded(lambda vm1: _CopyCertsToWorker(vm1, certs_dir), list(set(workers+[vm])))

  vm.PushFile(f"{certs_dir}/client.key", f"{certs_dir}/client.key")
  _RobustRemoteCommand(vm, f"kubectl create secret tls registry-cert --cert={certs_dir}/client.cert --key={certs_dir}/client.key")

  registry_yaml = REGISTRY_YAML.format(HOSTIP=vm.internal_ip, HOSTPORT=port).replace('"', '\\"')
  vm.RemoteCommand(f"bash -c 'kubectl create -f <(printf \"{registry_yaml}\")'")
  _RobustRemoteCommand(vm, f"kubectl wait pod --for=condition=ready -l app=registry")
  return registry_url


@vm_util.Retry()
def _RobustRemoteCommand(vm, cmd):
  vm.RemoteCommand(cmd)


def Uninstall(vm):
  try:
    vm.RemoteCommand("sudo kubeadm reset --force")
  except:
    vm.RemoteCommand("sudo rm -rf /etc/kubernetes $HOME/.config", ignore_failure=True)
    vm.RemoteCommand("sudo kubeadm reset --force", ignore_failure=True)
  vm.RemoteCommand("sudo ip link delete cni0", ignore_failure=True)
  vm.RemoteCommand("sudo rm -rf /etc/cni /var/lib/cni", ignore_failure=True)

  if FLAGS.k8s_cni == "Flannel":
    vm.RemoteCommand("sudo ip link delete flannel.1", ignore_failure=True)

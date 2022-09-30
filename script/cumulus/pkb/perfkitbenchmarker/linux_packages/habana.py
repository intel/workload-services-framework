from absl import flags
from perfkitbenchmarker import os_types

FLAGS = flags.FLAGS
flags.DEFINE_string("habana_version", "1.3.0-499", "Specify the Habana driver version")

TEST_HABANA_YAML = """
apiVersion: batch/v1
kind: Job
metadata:
  name: test-habana
spec:
  template:
    spec:
      containers:
      - name: test-habana
        image: busybox
        command: [ "true" ]
        resources:
          limits:
            habana.ai/gaudi: 1
          requests:
            habana.ai/gaudi: 1
      restartPolicy: Never
""".replace('\n', '\\n')

HABANA_REPO = '''[vault]
name=Habana Vault
baseurl=https://vault.habana.ai/artifactory/centos/8/8.3
enabled=1
gpgcheck=0
gpgkey=https://vault.habana.ai/artifactory/centos/8/8.3/repodata/repomod.xml.key
repo_gpgcheck=0'''

CONTAINERD_CONFIG = '''disabled_plugins = []
version = 2

   [plugins]
   [plugins."io.containerd.grpc.v1.cri"]
      [plugins."io.containerd.grpc.v1.cri".containerd]
         default_runtime_name = "habana"
         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.habana]
            runtime_type = "io.containerd.runc.v2"
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.habana.options]
               BinaryName = "/usr/bin/habana-container-runtime"
   [plugins."io.containerd.runtime.v1.linux"]
      runtime = "habana-container-runtime"'''

DOCKER_DAEMON = '''{
   "default-runtime": "habana",
   "runtimes": {
      "habana": {
            "path": "/usr/bin/habana-container-runtime",
            "runtimeArgs": []
      }
   }
}'''


def RegisterKubernetesPlugins(vm):
  vm.RemoteCommand("kubectl apply -f https://vault.habana.ai/artifactory/docker-k8s-device-plugin/habana-k8s-device-plugin.yaml")
  vm.RemoteCommand(f"printf '{TEST_HABANA_YAML}' | kubectl apply -f -")
  vm.RemoteCommand("timeout 300s bash -c 'until kubectl wait job test-habana --for=condition=complete; do sleep 1s; done'", ignore_failure=True)
  vm.RemoteCommand(f"printf '{TEST_HABANA_YAML}' | kubectl delete -f -")


def RegisterWithContainerD(vm):
  vm.RemoteCommand(f"echo '{CONTAINERD_CONFIG}' | sudo tee /etc/containerd/config.toml")
  vm.RemoteCommand("sudo systemctl restart containerd")
  vm.RemoteCommand("sleep 5s")
  vm.RemoteCommand("sudo systemctl restart kubelet")
  vm.RemoteCommand("sleep 5s")


def RegisterWithDocker(vm):
  vm.RemoteCommand(f"echo '{DOCKER_DAEMON}' | sudo tee /etc/docker/daemon.json")
  vm.RemoteCommand("sudo systemctl restart docker")
  vm.RemoteCommand("sleep 5s")


def _InstallCentosKernelDev(vm):
  mirror_base = 'https://mirrors.portworx.com/mirrors/http/mirror.centos.org/centos/'
  if os_types.CENTOS7 == vm.OS_TYPE:
    os_repo = '7'
  elif os_types.CENTOS8 == vm.OS_TYPE:
    os_repo = '8'
  elif os_types.CENTOS_STREAM8 == vm.OS_TYPE:
    os_repo = '8-stream'
  else:
    return False

  base_arq_pkg = '/BaseOS/x86_64/os/Packages/'
  kernel_devel = 'kernel-devel-$(uname -r).rpm'
  vm.InstallPackages('wget')
  pkg_url = mirror_base + os_repo + base_arq_pkg + kernel_devel
  _, _, wget_rc = vm.RemoteCommandWithReturnCode('wget {} -O /tmp/{}'.format(pkg_url, kernel_devel),
                                                 ignore_failure=True)
  if wget_rc:
    return False

  _, _, yum_rc = vm.RemoteCommandWithReturnCode('sudo yum -y install /tmp/{}'.format(kernel_devel),
                                                ignore_failure=True)
  vm.RemoteCommand('rm /tmp/{}'.format(kernel_devel))

  if yum_rc:
    return False

  return True


def YumInstall(vm):
  if vm.OS_TYPE != os_types.CENTOS_STREAM8:
    raise Exception("Only CentOS 8 Stream is supported!")

  # Install kernel devel for CentOS
  if not _InstallCentosKernelDev(vm):
    raise Exception("Failed to install kernel-devel for CentOS")

  habana_centos_version = FLAGS.habana_version + ".el8"
  vm.RemoteCommand(f"echo '{HABANA_REPO}' | sudo tee /etc/yum.repos.d/Habana-Vault.repo")
  vm.RemoteCommand("sudo yum makecache")
  vm.InstallPackages("--enablerepo=extras epel-release")
  vm.InstallPackages("dkms habanalabs-firmware-{0} habanalabs-firmware-tools-{0}".
                   format(habana_centos_version))
  vm.RemoteCommand("sudo yum install -y habanalabs-{0} habanalabs-graph-{0} habanalabs-container-runtime-{0}".
                   format(habana_centos_version))
  vm.RemoteCommand("sudo modprobe habanalabs_en")
  vm.RemoteCommand("sudo modprobe habanalabs")


def AptInstall(vm):
  vm.RemoteCommand('curl -X GET https://vault.habana.ai/artifactory/api/gpg/key/public | sudo apt-key add - && echo "deb https://vault.habana.ai/artifactory/debian $(grep VERSION_CODENAME= /etc/os-release | cut -f2 -d=) main" | sudo tee -a /etc/apt/sources.list.d/artifactory.list > /dev/null && sudo dpkg --configure -a')
  vm.AptUpdate()
  vm.InstallPackages("dkms libelf-dev")
  vm.InstallPackages("habanalabs-firmware={0} habanalabs-firmware-tools={0}".format(FLAGS.habana_version))
  vm.InstallPackages("--allow-downgrades habanalabs-thunk={0} habanalabs-dkms={0} habanalabs-graph={0} habanalabs-container-runtime={0}".format(FLAGS.habana_version))
  vm.RemoteCommand("sudo modprobe habanalabs_en")
  vm.RemoteCommand("sudo modprobe habanalabs")


def Uninstall(vm):
  pass

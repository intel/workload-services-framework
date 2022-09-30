from perfkitbenchmarker.linux_packages import proxy
from absl import flags

FLAGS = flags.FLAGS
flags.DEFINE_string("containerd_version", "1.5",
                    "Specify the containerd version")

CONFIG_FILE = "/etc/containerd/config.toml"


def YumInstall(vm):
  raise Exception("Not Implemented")


def AptInstall(vm):
  vm.AptUpdate()
  version, _ = vm.RemoteCommand(f"sudo apt-cache madison containerd | grep {FLAGS.containerd_version} | cut -f2 -d'|' | tr -d ' ' | sort -V -r | head -n 1")
  version = version.strip()
  vm.InstallPackages(f'containerd={version}')
  _ConfigureContainerd(vm)


def _ConfigureContainerd(vm):
  vm.RemoteCommand(f"sudo mkdir -p $(dirname {CONFIG_FILE})")
  vm.RemoteCommand(f"containerd config default | sudo tee {CONFIG_FILE}")
  vm.RemoteCommand(f"sudo sed -i 's/SystemdCgroup = .*/SystemdCgroup = true/' {CONFIG_FILE}")
  proxy.AddProxy(vm, "containerd")
  vm.RemoteCommand(f"sudo systemctl daemon-reload")
  vm.RemoteCommand(f"sudo systemctl restart containerd")


def Uninstall(vm):
  pass


from perfkitbenchmarker.linux_packages import proxy
from absl import flags
import json

FLAGS = flags.FLAGS
flags.DEFINE_string('docker_dist_repo', None,
                    'Path to the dockerce repository.')
flags.DEFINE_string('docker_version', '20.10',
                  'Specify the docker version.')
flags.DEFINE_list('docker_registry_mirrors', [],
                  'Specify the docker mirrors.')


def YumInstall(vm):
  repo = FLAGS.docker_dist_repo if FLAGS.docker_dist_repo else "https://download.docker.com/linux/centos"
  vm.InstallPackages("yum-utils device-mapper-persistent-data lvm2")
  # Package for RHEL8 containerd.io does not yet exist - this is a workaround
  if vm.OS_TYPE == "centos8" or vm.OS_TYPE == "rhel8":
    cmd = "sudo yum install -y " + repo + "/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm"
    cmd += " && sudo yum-config-manager --add-repo " + repo + "/docker-ce.repo"
  else:
    cmd = 'sudo yum-config-manager --add-repo ' + repo + '/docker-ce.repo'
  vm.RemoteCommand(cmd)
  vm.InstallPackages('docker-ce')

  proxy.AddProxy(vm, "docker")
  AddConfig(vm)
  _AddUserToDockerGroup(vm)


def AptInstall(vm):
  repo = FLAGS.docker_dist_repo if FLAGS.docker_dist_repo else "https://download.docker.com/linux/ubuntu"
  vm.InstallPackages("apt-transport-https ca-certificates curl gnupg-agent software-properties-common")
  vm.RemoteCommand(f'curl -fsSL {repo}/gpg | sudo apt-key add -')
  vm.RemoteCommand(f"bash -c 'sudo -E add-apt-repository \"deb [arch=$(dpkg --print-architecture)] {repo} $(grep CODENAME /etc/lsb-release | cut -f2 -d=) stable\"'")
  vm.AptUpdate()
  version, _ = vm.RemoteCommand(f"sudo apt-cache madison docker-ce | grep {FLAGS.docker_version} | cut -f2 -d'|' | tr -d ' ' | sort -V -r | head -n 1")
  vm.InstallPackages(f'docker-ce={version.strip()} --allow-change-held-packages')

  proxy.AddProxy(vm, "docker")
  AddConfig(vm)
  _AddUserToDockerGroup(vm)


def SwupdInstall(vm):
  vm.RemoteCommand("sudo swupd update")
  vm.InstallPackages("containers-basic")

  proxy.AddProxy(vm, "docker")
  AddConfig(vm)
  _AddUserToDockerGroup(vm)


def AddConfig(vm, config={}):
  config["exec-opts"] = ["native.cgroupdriver=systemd"]
  if FLAGS.docker_registry_mirrors:
    config["registry-mirrors"] = FLAGS.docker_registry_mirrors

  vm.RemoteCommand(f"echo '{json.dumps(config)}' | sudo tee /etc/docker/daemon.json")
  vm.RemoteCommand(f"sudo systemctl daemon-reload")
  vm.RemoteCommand(f"sudo systemctl restart docker")
  
  
def _AddUserToDockerGroup(vm):
  """
  Add user to the docker group so docker commands can be executed without sudo
  """
  vm.RemoteCommand("sudo usermod --append --groups docker {}".format(vm.user_name))
  vm.RemoteCommand("sudo systemctl restart docker")

  # SSH uses multiplexing to reuse connections without going through the SSH handshake
  # for a remote host. Typically we need to logout / login after adding the user to
  # the docker group as group memberships are evaluated at login.
  # See: https://docs.docker.com/engine/install/linux-postinstall/
  # This requirement along with the multiplexing causes subsequent docker commands run in the
  # reused session to fail with "permission denied" errors.
  # This command will cause the ssh multiplexing for this particular VM to stop causing the next
  # SSH command to the VM to restart a multiplex session with ControlMaster=auto. This new session
  # will start with docker group membership and will be able to execute docker commands without root.
  vm.RemoteCommand('', ssh_args = ['-O', 'stop'])


def IsDocker(vm):
  return "docker_ce" in vm._installed_packages


def Uninstall(vm):
  pass

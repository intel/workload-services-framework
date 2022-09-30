# Copyright 2016 PerfKitBenchmarker Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Package for installing the AWS CLI."""

AWSCLI_URL_FMT = "https://awscli.amazonaws.com/awscli-exe-linux-{arch}.zip"
AWSCLI_ZIP = "awscliv2.zip"


def Install(vm):
  """Installs the awscli package on the VM."""
  uname = vm.RemoteCommand('uname -m')[0].strip()
  if uname != 'x86_64' and uname != 'aarch64':
    raise NotImplementedError("unsupported architecture: {}".format(uname))

  vm.InstallPackages("unzip")
  cli_url = AWSCLI_URL_FMT.format(arch=uname)
  vm.RemoteCommand(f"curl {cli_url} -o {AWSCLI_ZIP} && unzip {AWSCLI_ZIP}")
  vm.RemoteCommand("sudo ./aws/install")
  # Clean up unused files
  vm.RemoteCommand(f"rm -rf aws {AWSCLI_ZIP}")


def Uninstall(vm):
  vm.RemoteCommand('sudo rm -rf /usr/local/aws-cli')
  vm.RemoteCommand('sudo rm /usr/local/bin/aws')

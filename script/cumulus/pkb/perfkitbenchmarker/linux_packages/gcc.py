# Copyright 2018 PerfKitBenchmarker Authors. All rights reserved.
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

"""Module containing gcc installation and cleanup functions."""

""" This is a generic gcc installer and must offer installation
    methods for various versions of gcc """

from absl import flags
from perfkitbenchmarker import errors
from perfkitbenchmarker.linux_packages import INSTALL_DIR
import logging

FLAGS = flags.FLAGS


def _Install(vm):
  """Installs the gcc package on the VM."""
  pass


def YumInstall(vm):
  """Installs the gcc package on the VM."""
  # TODO: Figure out how to install gcc with yum
  raise NotImplementedError


def AptInstall(vm):
  """ Install gcc from the ppa ubuntu-toolchain repo """
  # On Ubuntu this is a symlink, save it for uninstall
  vm.RemoteCommand('test -L /usr/bin/gcc && readlink /usr/bin/gcc > {0}/gcc-symlink-target'.format(INSTALL_DIR),
                   ignore_failure=True)
  try:
    # try first if distributions/versions have gcc-8 in their default repository
    vm.AptUpdate()
    vm.RemoteCommand('sudo apt-get -y install {0}-{1}'
                     .format(FLAGS.compiler, FLAGS.compiler_version))
  except errors.VirtualMachine.RemoteCommandError:
    # try again if distributions/versions do NOT have gcc-8 in their default repository
    vm.RemoteCommand('sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y')
    vm.AptUpdate()
    vm.RemoteCommand('sudo apt-get -y install {0}-{1}'
                     .format(FLAGS.compiler, FLAGS.compiler_version))

  try:
    vm.RemoteCommand('if [[ -s {0}/gcc-symlink-target ]]; then cat {0}/gcc-symlink-target; fi'.format(INSTALL_DIR))[0].rstrip('\n')
    if vm.RemoteCommandWithReturnCode('test -L /usr/bin/gcc')[2] == 0:
      vm.RemoteCommand('sudo rm -f /usr/bin/gcc && sudo ln -s /usr/bin/gcc-{0} /usr/bin/gcc'.format(FLAGS.compiler_version))
    else:
      vm.RemoteCommand('sudo ln -s /usr/bin/gcc-{0} /usr/bin/gcc'.format(FLAGS.compiler_version))
  except errors.VirtualMachine.RemoteCommandError:
    # Install the distro default for gcc
    # This should ALWAYS work, unless there are bigger issues
    logging.warn("Falling back to your distro's default gcc!")
    vm.InstallPackages('gcc')


def SwupdInstall(vm):
  """ Installs a gcc containing bundle on the Clear Linux VM """
  raise NotImplementedError


def Uninstall(vm):
  gcc = vm.RemoteCommand('if [[ -s {0}/gcc-symlink-target ]]; then cat {0}/gcc-symlink-target; fi'.format(INSTALL_DIR))[0].rstrip('\n')
  if gcc != '':
    vm.RemoteCommand('sudo rm /usr/bin/gcc && sudo ln -s /usr/bin/{0} /usr/bin/gcc'.format(gcc), ignore_failure=True)

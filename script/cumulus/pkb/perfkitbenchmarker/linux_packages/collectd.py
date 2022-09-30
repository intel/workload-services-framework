# Copyright 2015 PerfKitBenchmarker Authors. All rights reserved.
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
"""Builds collectd from source, installs to linux_packages.INSTALL_DIR.

https://collectd.org/
collectd is extremely configurable. We enable some basic monitoring, gathered
every 10s, saving in .csv format. See
perfkitbenchmarker/data/build_collectd.sh.j2 for configuration details.
"""

import posixpath
import os
import re
import logging
import csv

from absl import flags
from perfkitbenchmarker import data

flags.DEFINE_string('collectd_depend', None,
                    'list collectd dependency files required to add plugin in configuration file.')
flags.DEFINE_string('collectd_config', None,
                    'override the default collectd configuration file.')
flags.DEFINE_string('collectd_tar', None,
                    'Path on PKB host from which user can upload collectd package to SUT')

FLAGS = flags.FLAGS

COLLECTD_DIR = '/opt/collectd'
BUILD_SCRIPT_NAME = 'build_collectd.sh.j2'
PLUGIN_DIR_NAME = 'collectd_plugins'
PATCHES_DIR_NAME = 'collectd_patches'
COLLECTD_URL = ('https://storage.googleapis.com/collectd-tarballs/collectd-5.12.0.tar.bz2')
BUILD_DIR = posixpath.join(COLLECTD_DIR, 'collectd-build')
CSV_DIR = posixpath.join(COLLECTD_DIR, 'collectd-csv')
PREFIX = posixpath.join(COLLECTD_DIR, 'collectd')
PLUGIN_DIR = posixpath.join(COLLECTD_DIR, PLUGIN_DIR_NAME)
PATCHES_DIR = posixpath.join(COLLECTD_DIR, PATCHES_DIR_NAME)
PID_FILE = posixpath.join(PREFIX, 'var', 'run', 'collectd.pid')
PYTHON_CONFIG = "/usr/bin/python3-config"


def _GetAbsPath(path):
  absPath = os.path.abspath(os.path.expanduser(path))
  if not os.path.isfile(absPath):
    raise RuntimeError('File (%s) does not exist.' % path)
  return absPath


def _CollectdInstalled(vm):
  ret, _ = vm.RemoteCommand(f"test -d {COLLECTD_DIR} && echo collectd_installed || echo collectd_not_found",
                            ignore_failure=True)
  if "collectd_installed" in ret:
    return True
  return False


def Prepare(vm, benchmark_spec):
  """Prepares collect on VM."""
  pass


def _Install(vm):
  # if skip_install flag is true and collectd_dir exist, do nothing
  if FLAGS.trace_skip_install and _CollectdInstalled(vm):
    logging.info('Skip installing collectd')
    return

  # first clean up the existing collectd_dir
  vm.RemoteCommand(f"sudo rm -rf {COLLECTD_DIR}")
  vm.RemoteCommand(f"sudo mkdir -p {COLLECTD_DIR}; sudo chown -R {vm.user_name} {COLLECTD_DIR}")
  # copy config file
  if FLAGS.collectd_config:
    configFile_path = _GetAbsPath(FLAGS.collectd_config)
  else:
    configFile_path = data.ResourcePath('collectd.conf')
  vm.RemoteCopy(configFile_path, COLLECTD_DIR, True)
  # install user-defined package dependencies
  if FLAGS.collectd_depend:
    dependFile_path = _GetAbsPath(FLAGS.collectd_depend)
  else:
    dependFile_path = data.ResourcePath('collectdDepend.txt')
  # this file may not be there or it could be empty
  if posixpath.exists(dependFile_path) and posixpath.getsize(dependFile_path) > 0:
    with open(dependFile_path) as fh:
      for line in fh:
        if re.match(r"^\w+", line):
          vm.InstallPackages(line)
  # upload patches
  vm.RemoteCommand('bash -c "mkdir -p {0}"'.format(PATCHES_DIR))
  patches_path = data.ResourcePath(PATCHES_DIR_NAME)
  for file in os.listdir(patches_path):
    vm.RemoteCopy(posixpath.join(patches_path, file), posixpath.join(PATCHES_DIR, file), True)
  # upload plugins
  vm.RemoteCommand('bash -c "mkdir -p {0}"'.format(PLUGIN_DIR))
  plugins_path = data.ResourcePath(PLUGIN_DIR_NAME)
  for file in os.listdir(plugins_path):
    vm.RemoteCopy(posixpath.join(plugins_path, file), posixpath.join(PLUGIN_DIR, file), True)

  collectd_tar_package = posixpath.join(COLLECTD_DIR, 'collectd.tar.bz2')
  if FLAGS.collectd_tar:
    vm.RemoteCopy(data.ResourcePath(FLAGS.collectd_tar), '{0}'.format(collectd_tar_package))
  else:
    vm.RemoteCommand("curl -L {0} --output {1}".format(COLLECTD_URL, collectd_tar_package))

  if vm.OS_TYPE == "ubuntu2004":
     python_config = PYTHON_CONFIG + " --embed"
  else:
     python_config = PYTHON_CONFIG

  # build collectd
  context = {
      'collectd_package': collectd_tar_package,
      'build_dir': BUILD_DIR,
      'root_dir': PREFIX,
      'parent_dir': COLLECTD_DIR,
      'plugin_dir': PLUGIN_DIR,
      'patches_dir': PATCHES_DIR,
      'config_depd_file': os.path.basename(dependFile_path),
      'config_file': os.path.basename(configFile_path),
      'python_config': python_config}
  remote_path = posixpath.join(
      COLLECTD_DIR,
      posixpath.splitext(posixpath.basename(BUILD_SCRIPT_NAME))[0])
  vm.RenderTemplate(data.ResourcePath(BUILD_SCRIPT_NAME),
                    remote_path, context=context)
  vm.RemoteCommand('bash ' + remote_path)


def _Uninstall(vm):
  pass


def Start(vm):
  vm.RemoteCommand("%s/sbin/collectd -t" % PREFIX)  # exception will be thrown if this fails
  vm.RemoteCommand("%s/sbin/collectd" % PREFIX)


def Stop(vm):
  vm.RemoteCommand('kill -9 $(cat {0})'.format(PID_FILE), ignore_failure=True)


def YumInstall(vm):
  """Installs collectd on 'vm'."""
  vm.InstallPackages('libtool-ltdl-devel python3-devel python3-pip curl')
  vm.InstallPackageGroup('Development Tools')
  _Install(vm)


def AptInstall(vm):
  """Installs collectd on 'vm'."""
  pkg_list = "autoconf bison flex libtool pkg-config build-essential python3 python3-dev curl"
  vm.InstallPackages(pkg_list)
  _Install(vm)


def AptUninstall(vm):
  """Stops collectd on 'vm'."""
  _Uninstall(vm)


def YumUninstall(vm):
  """Stops collectd on 'vm'."""
  _Uninstall(vm)


def SwupdInstall(vm):
  """Installs collectd on 'vm'."""
  vm.InstallPackages('os-testsuite-phoronix-server')
  _Install(vm)


def SwupdUninstall(vm):
  """Stops collectd on 'vm'."""
  _Uninstall(vm)

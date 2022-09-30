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


"""Module containing STREAM installation and cleanup functions."""

from perfkitbenchmarker.linux_packages import INSTALL_DIR
from absl import flags
from perfkitbenchmarker import errors
from perfkitbenchmarker import os_types
from perfkitbenchmarker import vm_util

FLAGS = flags.FLAGS

STREAM_DIR = '%s/STREAM' % INSTALL_DIR
STREAM_PATH = STREAM_DIR + '/stream'
GIT_REPO = 'https://github.com/jeffhammond/STREAM.git'


def GetStreamExec(vm):
  if FLAGS.stream_omp_num_threads == 0:
    num_threads = vm.num_cpus
  else:
    num_threads = FLAGS.stream_omp_num_threads

  if num_threads <= 1:
    raise errors.Setup.InvalidSetupError(
        'Stream could not be run on machine with CPU/Threads number <= 1')

  if FLAGS.stream_binary_url:
    source_psxe_vars = "source /opt/intel/psxe_runtime/linux/bin/psxevars.sh"
    return 'export OMP_NUM_THREADS={0};export GOMP_CPU_AFFINITY="0-{1}:1";{2} && {3}'.format(num_threads,
                                                                                             num_threads - 1,
                                                                                             source_psxe_vars,
                                                                                             STREAM_PATH)
  else:
    return 'export OMP_NUM_THREADS={0};export GOMP_CPU_AFFINITY="0-{1}:1";{2}'.format(num_threads,
                                                                                      num_threads - 1,
                                                                                      STREAM_PATH)


def _GetInternalResources(vm, url):
  stream_path = vm_util.PrependTempDir('stream')
  vm_util.IssueCommand("curl -SL {0} -o {1}".format(url, stream_path).split(), timeout=None)
  vm.RemoteCommand("mkdir -p {0}".format(STREAM_DIR))
  vm.RemoteCopy(stream_path, STREAM_PATH)
  vm.RemoteCommand("sudo chmod +x {0}".format(STREAM_PATH))


def _Install(vm):
  """Installs the stream package on the VM."""
  if FLAGS.stream_binary_url:
    vm.Install('intel_parallel_studio_runtime')
    _GetInternalResources(vm, FLAGS.stream_binary_url)
  else:
    vm.RemoteCommand('git clone {0} {1}'.format(GIT_REPO, STREAM_DIR))
    vm.RemoteCommand('cd {0}; {1} {2} '
                     '-DSTREAM_ARRAY_SIZE={3} -DNTIMES={4} -DOFFSET={5} '
                     'stream.c -o stream'.format(STREAM_DIR,
                                                 FLAGS.compiler,
                                                 FLAGS.stream_compiler_flags,
                                                 FLAGS.stream_array_size,
                                                 FLAGS.stream_ntimes,
                                                 FLAGS.stream_offset)
                     )


def YumInstall(vm):
  """Installs the stream package on the VM."""
  # for RHEL 7
  if vm.OS_TYPE == os_types.RHEL:
    raise NotImplementedError
  vm.Install('build_tools')
  _Install(vm)


def AptInstall(vm):
  """Installs the stream package on the VM."""
  vm.Install('build_tools')
  vm.Install('compiler')
  _Install(vm)


def Uninstall(vm):
  vm.RemoteCommand('sudo rm -rf {0}'.format(STREAM_DIR))

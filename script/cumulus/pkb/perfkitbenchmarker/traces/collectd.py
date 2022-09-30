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
"""Records system performance counters during benchmark runs using collectd.

http://collectd.org
"""

import logging
import os
import posixpath
from absl import flags
from perfkitbenchmarker import events
from perfkitbenchmarker import stages
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import trace_util
from perfkitbenchmarker.linux_packages import collectd

FLAGS = flags.FLAGS
flags.DEFINE_boolean('collectd', False,
                     'Install and run collectd on the guest.')
flags.DEFINE_string('collectd_output', None, 'Path to store collectd results.')


class _CollectdCollector(object):
  """Manages running collectd during a test, and fetching the CSV results."""

  def __init__(self, target_dir):
    self.target_dir = target_dir

  def _FetchResults(self, vm):
    """Fetches collectd CSV results."""
    logging.info('Fetching collectd results')
    # On the remote host, CSV files are in:
    # self.csv_dir/<fqdn>/<category>.
    # Since AWS VMs have a FQDN different from the VM name, we rename locally.
    archive_name = vm.name + '-collectd.tar.gz'
    vm.RemoteCommand('tar -czvf {0} -C {1} .'.format(archive_name, collectd.CSV_DIR))
    local_dir = os.path.join(self.target_dir, vm.name + '-collectd')
    cmd = ["mkdir",
           "-p",
           local_dir]
    vm_util.IssueCommand(cmd, raise_on_failure=False)
    vm.PullFile(local_dir, archive_name)
    cmd = ['tar',
           '-xzvf',
           posixpath.join(local_dir, archive_name),
           '-C',
           local_dir,
           '--strip',
           '2']
    vm_util.IssueCommand(cmd)
    logging.info('Removing collectd data from target.')
    vm.RemoteCommand('rm -rf {}'.format(collectd.CSV_DIR))
    vm.RemoteCommand('rm -rf pkb-*-collectd.tar.gz')
    if not FLAGS.trace_skip_cleanup:
      vm.RemoteCommand("sudo rm -rf {}".format(collectd.COLLECTD_DIR))


  def _StartCollectd(self, vm):
    """Starts collectd on the VM."""
    logging.info('Starting collectd')
    collectd.Start(vm)

  def _StopCollectd(self, vm):
    """Stops collectd on the VM."""
    logging.info('Stopping collectd')
    collectd.Stop(vm)

  def _InstallCollectd(self, vm):
    """Installs collect on VM."""
    logging.info('Installing collectd')
    vm.Install('collectd')

  def _PrepareCollectd(self, vm, benchmark_spec):
    """Prepares collect on VM."""
    logging.info('Preparing collectd')
    collectd.Prepare(vm, benchmark_spec)

  def Install(self, unused_sender, benchmark_spec):
    """Install, prepare, and start collectd.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    # install
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._InstallCollectd, vms)

    # prepare
    prepare_params = [((vm,), {"benchmark_spec": benchmark_spec}) for vm in vms]

    vm_util.RunThreaded(self._PrepareCollectd, prepare_params)

  def Start(self, unused_sender, benchmark_spec):
    """Start collectd

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._StartCollectd, vms)

  def After(self, unused_sender, benchmark_spec):
    """Stop collectd, fetch results from VMs.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._StopCollectd, vms)
    vm_util.RunThreaded(self._FetchResults, vms)


def Register(parsed_flags):
  """Register the collector if FLAGS.collectd is set."""
  if not parsed_flags.collectd:
    return

  logging.info('Registering collectd collector')

  output_directory = parsed_flags.collectd_output or vm_util.GetTempDir()
  if not os.path.isdir(output_directory):
    raise IOError('collectd output directory does not exist: {0}'.format(
        output_directory))
  collector = _CollectdCollector(output_directory)
  events.before_phase.connect(collector.Install, stages.RUN, weak=False)
  events.start_trace.connect(collector.Start, stages.RUN, weak=False)
  events.stop_trace.connect(collector.After, stages.RUN, weak=False)


def IsEnabled():
  return FLAGS.collectd

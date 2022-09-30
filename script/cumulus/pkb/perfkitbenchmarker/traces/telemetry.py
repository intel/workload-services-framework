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

import logging
import os

from perfkitbenchmarker import events, stages
from absl import flags
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import data

FLAGS = flags.FLAGS

flags.DEFINE_boolean('telemetry', False,
                     'Install and run emon,containerized-collectd and sar on the guest.')

ARCHIVE_LINK = "https://gitlab.devtools.intel.com/cumulus/external_dependencies/telemetry/raw/master/telemetry.tar.gz"
PREREQ_PKGS = ["gcc",
               "make",
               "yp-tools",
               "sysstat",
               "dstat"]


class _TelemetryCollector(object):
  """Manages running telemetry during a test, and fetching the results folder."""

  def __init__(self, output_directory):
    self.output_directory = output_directory

  def _FetchResults(self, vm):
    """Fetches telemetry results."""
    logging.info('Fetching telemetry results')
    telemetry_dir = '~/' + vm.name + '-telemetry'
    vm.RemoteCommand(('mkdir {0} ').format(telemetry_dir))
    vm.RemoteCommand(('sudo mv /tmp/results {0} ').format(telemetry_dir))
    vm.RemoteCommand(('sudo mv /tmp/telemetry.log {0} ').format(telemetry_dir))
    vm.RemoteCopy(vm_util.GetTempDir(), telemetry_dir, False)
    logging.info('Telemetry Files Copied')

  def _InstallTelemetry(self, vm):
    """Installs Telemetry on the VM."""
    logging.info('Installing telemetry')
    try:
      telemetry_path = data.ResourcePath('telemetry/telemetry.tar.gz')
    except data.ResourceNotFound:
      tmp_dir = vm_util.GetTempDir()
      vm_util.IssueCommand("wget -P {0} {1}".format(tmp_dir, ARCHIVE_LINK).split())
      telemetry_path = os.path.join(tmp_dir, ARCHIVE_LINK[ARCHIVE_LINK.rindex("/") + 1:])

    vm.RemoteCommand('sudo rm -rf /opt/intel')
    vm.RemoteCommand('sudo mkdir -p /opt/intel')
    vm.RemoteCopy(telemetry_path, '~', True)
    vm.RemoteCommand('sudo cp ./telemetry.tar.gz /opt/intel/')
    vm.RemoteCommand('cd /opt/intel && sudo tar -xf telemetry.tar.gz && sudo chmod -R 777 /opt/intel/telemetry')
    vm.InstallPackages(' '.join(PREREQ_PKGS))

  def _StopTelemetry(self, vm):
    """Stops Telemetry on the VM."""
    logging.info('Stopping telemetry')
    vm.RemoteCommand('sudo /opt/intel/telemetry/scripts/cleanup_Telemetry.sh')

  def _StartTelemetry(self, vm):
    vm.RemoteCommand('sudo /opt/intel/telemetry/scripts/main.sh')

  def Install(self, unused_sender, benchmark_spec):
    """Install Telemetry.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    logging.info('Installing telemetry')
    vm_util.RunThreaded(self._InstallTelemetry, benchmark_spec.vms)

  def Start(self, unused_sender, benchmark_spec):
    """Start Telemetry

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    logging.info('Starting telemetry')
    vm_util.RunThreaded(self._StartTelemetry, benchmark_spec.vms)

  def After(self, unused_sender, benchmark_spec):
    """Stop telemetry, fetch results from VMs.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    vm_util.RunThreaded(self._StopTelemetry, benchmark_spec.vms)
    vm_util.RunThreaded(self._FetchResults, benchmark_spec.vms)


def Register(parsed_flags):
  """Register the collector if FLAGS.telemetry is set."""
  if not parsed_flags.telemetry:
    return

  raise ValueError("--telemetry flag is disabled for now because of old Emon version. Use --emon flag instead.")

  logging.info('Registering telemetry collector')

  output_directory = vm_util.GetTempDir()
  telemetry_collector = _TelemetryCollector(output_directory)
  events.before_phase.connect(telemetry_collector.Install, stages.RUN, weak=False)
  events.start_trace.connect(telemetry_collector.Start, stages.RUN, weak=False)
  events.stop_trace.connect(telemetry_collector.After, stages.RUN, weak=False)


def IsEnabled():
  return FLAGS.telemetry

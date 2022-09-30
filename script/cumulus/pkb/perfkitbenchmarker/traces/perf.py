"""Records Linux profile with performance counters using the perf tool.
"""

import logging
import os

from perfkitbenchmarker import events, stages
from perfkitbenchmarker import errors
from absl import flags
from perfkitbenchmarker import vm_util
from perfkitbenchmarker.traces import base_collector

FLAGS = flags.FLAGS

flags.DEFINE_boolean('perf', False,
                     'Install and run perf on the guest.')
flags.DEFINE_string('perf_output', None, 'Path to store perf results.')
flags.DEFINE_string('perf_options', "", 'perf options.')


class _PerfCollector(base_collector.BaseCollector):
  """Manages running perf during a test, and fetching the results."""

  def _CollectorName(self):
    return 'perf'

  def _InstallCollector(self, vm):
    vm.Install('perf')

  def _CollectorRunCommand(self, vm, collector_file):
    return f'sudo perf record {FLAGS.perf_options} --output {collector_file} > /dev/null 2>&1 & echo $!'

  # override base class method so we can execute a few extra required steps
  def _StopOnVm(self, vm, vm_role):
    """Stop collector on 'vm' and copy the files back."""
    if vm.name not in self._pid_files:
      logging.warn('No collector PID for %s', vm.name)
      return
    else:
      with self._lock:
        pid, file_name = self._pid_files.pop(vm.name)
    cmd = 'sudo kill -INT {0} || true'.format(pid)
    vm.RemoteCommand(cmd)
    try:
      vm.RemoteCommand('sudo chmod -R a+rw {0}'.format(file_name))
      vm.PullFile(self.output_directory, file_name)
      self._role_mapping[vm_role] = file_name
      report_file = file_name + ".txt"
      vm.RemoteCommand('sudo perf report -i {0} > {1}'.format(file_name, report_file))
      vm.PullFile(self.output_directory, report_file)
    except errors.VirtualMachine.RemoteCommandError as ex:
      logging.exception('Failed fetching collector result from %s.', vm.name)
      raise ex


def Register(parsed_flags):
  """Register the collector if FLAGS.perf is set."""
  if not parsed_flags.perf:
    return

  logging.info('Registering perf collector')

  output_directory = parsed_flags.perf_output or vm_util.GetTempDir()
  if not os.path.isdir(output_directory):
    os.makedirs(output_directory)
  collector = _PerfCollector(output_directory)
  events.before_phase.connect(collector.Install, stages.RUN, weak=False)
  events.start_trace.connect(collector.Start, stages.RUN, weak=False)
  events.stop_trace.connect(collector.Stop, stages.RUN, weak=False)


def IsEnabled():
  return FLAGS.perf

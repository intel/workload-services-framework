# PerfSpect-PKB integration
"""
Intel PerfSpect is a system performance profiling and processing tool based on linux perf.

Usage:
  Required flags:
  --intel_perfspect

  Example:
  ./pkb.py --cloud=AWS --benchmarks=sysbench_cpu --machine_type=m5.2xlarge --os_type=ubuntu2004 --intel_perfspect

  Refer to ./perfkitbenchmarker/data/intel_perfspect/README.md for more details on flags and usage
"""

import logging
import os
import posixpath

from absl import flags
from six.moves.urllib.parse import urlparse

from perfkitbenchmarker import events, stages
from perfkitbenchmarker import errors
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import data
from perfkitbenchmarker import trace_util
from perfkitbenchmarker import os_types

FLAGS = flags.FLAGS

flags.DEFINE_boolean('intel_perfspect', False,
                     'Install and run Intel perfspect on the target system.')
flags.DEFINE_string('intel_perfspect_tarball', None,
                    'Local path to Intel perfspect tarball.')
flags.DEFINE_string('intel_perfspect_url', None,
                    'URL for downloading Intel perfspect tarball.')

PERFSPECT_ARCHIVE_URL = "https://cumulus.s3.us-east-2.amazonaws.com/perfspect/perfspect_internal_1.3.0.tgz"
PREREQ_UBUNTU = ["linux-tools-common",
                 "linux-tools-generic",
                 "linux-tools-`uname -r`"]
PREREQ_CENTOS = ["perf"]
PREREQ_PKGS = ["python3-pip"]


class PerfspectCollector(object):
  """ Manages running telemetry during a test, and fetching the results folder. """

  telemetry_dir = "/opt/perf_telemetry"

  def __init__(self):
    self.pid = None
    self.perf_dir = None

  def _InstallOSReqs(self, vm):
    """ Installs prereqs depending on the OS """
    if vm.OS_TYPE in os_types.LINUX_OS_TYPES:
      if vm.OS_TYPE.find('ubuntu') >= 0:
        vm.InstallPackages(' '.join(PREREQ_UBUNTU))
      elif vm.OS_TYPE.find('centos') >= 0:
        vm.InstallPackages(' '.join(PREREQ_CENTOS))
    else:
      raise errors.VirtualMachine.VirtualMachineError('OS not supported')

  def _InstallTelemetry(self, vm):
    """ Installs PerfSpect telemetry on the VM. """
    logging.info('Installing PerfSpect on VM')
    self._InstallOSReqs(vm)
    vm.InstallPackages(' '.join(PREREQ_PKGS))
    vm.RemoteCommand(' '.join(["sudo", "rm", "-rf", self.telemetry_dir]))
    vm.RemoteCommand(' '.join(["sudo", "mkdir", "-p", self.telemetry_dir]))
    vm.PushFile(self.perf_dir)
    vm.RemoteCommand(' '.join(["sudo", "cp", "-r", "./perfspect", self.telemetry_dir + "/"]))

  def _StartTelemetry(self, vm):
    """ Starts PerfSpect telemetry on the VM. """
    try:
      # verify perf binary is executable
      vm.RemoteCommand('perf list')
    except errors.VirtualMachine.RemoteCommandError as ex:
      logging.exception('Failed executing perf. Is it installed?')
      raise ex
    perf_collect_file = posixpath.join(self.telemetry_dir, 'perfspect', 'perf-collect.sh')
    vm.RemoteCommand('sudo chmod +x {0}'.format(perf_collect_file))
    collect_cmd = ['cd', posixpath.join(self.telemetry_dir, 'perfspect'), '&&', 'sudo', './perf-collect.sh']
    stdout, _ = vm.RemoteCommand(' '.join(collect_cmd), should_log=True)
    self.pid = stdout.strip()
    logging.debug("pid of PerfSpect collector process: {0}".format(self.pid))

  def _StopTelemetry(self, vm):
    """ Stops PerfSpect telemetry on the VM. """
    logging.info('Stopping PerfSpect telemetry')
    vm.RemoteCommand('sudo pkill -9 -x perf')
    logging.debug('Waiting until the process is killed')
    wait_cmd = ['tail', '--pid=' + self.pid, '-f', '/dev/null']
    vm.RemoteCommand(' '.join(wait_cmd))
    logging.info('Post processing PerfSpect raw metrics')
    postprocess_cmd = ['cd', posixpath.join(self.telemetry_dir, 'perfspect'), '&&', 'sudo', './perf-postprocess',
                       '-r', 'results/perfstat.csv']
    vm.RemoteCommand(' '.join(postprocess_cmd))

  def _FetchResults(self, vm):
    """ Fetches PerfSpect telemetry results. """
    logging.info('Fetching PerfSpect telemetry results')
    perfspect_dir = '~/' + vm.name + '-perfspect'
    vm.RemoteCommand(('mkdir {0} ').format(perfspect_dir))
    vm.RemoteCommand(' '.join(["sudo", "cp", "-r", posixpath.join(self.telemetry_dir, 'perfspect', 'results', '*'),
                     perfspect_dir]))
    vm.RemoteCopy(vm_util.GetTempDir(), perfspect_dir, False)
    logging.info('PerfSpect results copied')

  def _CleanupTelemetry(self, vm):
    """ PerfSpect cleanup routines """
    logging.info('Removing PerfSpect leftover files')
    vm_util.IssueCommand(["rm", "-rf", self.perf_dir, self.perfspect_archive])
    vm.RemoteCommand(' '.join(["sudo", "rm", "-rf", "~/*perfspect"]))
    if not FLAGS.trace_skip_cleanup:
      logging.info('Removing PerfSpect from VM')
      vm.RemoteCommand(' '.join(["sudo", "rm", "-rf", self.telemetry_dir]))

  def _GetLocalArchive(self):
    """ Gets the local path of the PerfSpect archive. """
    if FLAGS.intel_perfspect_tarball:
      logging.info("intel_perfspect_tarball specified: {}".format(FLAGS.intel_perfspect_tarball))
      local_archive_path = FLAGS.intel_perfspect_tarball
    else:
      url = FLAGS.intel_perfspect_url or PERFSPECT_ARCHIVE_URL
      logging.info("downloading PerfSpect from: {}".format(url))
      filename = os.path.basename(urlparse(url).path)
      local_archive_path = posixpath.join(vm_util.GetTempDir(), filename)
      vm_util.IssueCommand(["curl", "-k", "-L", "-o", local_archive_path, url], timeout=None)
    return local_archive_path

  def _PerfspectDirExist(self, vms):
    for vm in vms:
      _, _, retVal = vm.RemoteCommandWithReturnCode('test -d {0}'.format(self.telemetry_dir),
                                                    ignore_failure=True)
      # if perfspect directory does not exist on any vm, we need install
      if retVal != 0:
        return False
    # if exist on all vms
    return True

  def Install(self, unused_sender, benchmark_spec):
    """ Installs PerfSpect Telemetry.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    logging.info('Installing PerfSpect telemetry')
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    if FLAGS.trace_skip_install and self._PerfspectDirExist(vms):
      logging.info('Skipping PerfSpect telemetry installation')
      return

    self.perf_dir = posixpath.join(vm_util.GetTempDir(), 'perfspect')
    self.perfspect_archive = self._GetLocalArchive()
    vm_util.IssueCommand(["tar", "-C", vm_util.GetTempDir(), "-xf", self.perfspect_archive])
    vm_util.IssueCommand(['cp', data.ResourcePath(posixpath.join('intel_perfspect', 'perf-collect.sh')),
                          self.perf_dir + "/"])
    vm_util.RunThreaded(self._InstallTelemetry, vms)

  def Start(self, unused_sender, benchmark_spec):
    """ Starts PerfSpect Telemetry

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    logging.info('Starting PerfSpect telemetry')
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._StartTelemetry, vms)

  def After(self, unused_sender, benchmark_spec):
    """ Stops PerfSpect telemetry, fetch results from VM(s).

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._StopTelemetry, vms)
    vm_util.RunThreaded(self._FetchResults, vms)

  def Remove(self, unused_sender, benchmark_spec):
    """Remove PerfSpect from VMs.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._CleanupTelemetry, vms)


def Register(parsed_flags):
  """ Registers the PerfSpect collector if FLAGS.intel_perfspect is set. """
  if not parsed_flags.intel_perfspect:
    return
  logging.info('Registering PerfSpect telemetry collector')
  telemetry_collector = PerfspectCollector()
  events.before_phase.connect(telemetry_collector.Install, stages.RUN, weak=False)
  events.start_trace.connect(telemetry_collector.Start, stages.RUN, weak=False)
  events.stop_trace.connect(telemetry_collector.After, stages.RUN, weak=False)
  events.before_phase.connect(telemetry_collector.Remove, stages.CLEANUP, weak=False)


def IsEnabled():
  return FLAGS.intel_perfspect

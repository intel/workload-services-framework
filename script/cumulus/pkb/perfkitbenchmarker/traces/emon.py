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
"""
Records system performance counters during benchmark runs using emon.

Usage:
  Required flags:
  --emon

  Example:
  ./pkb.py --cloud=AWS --machine_type=m5.metal --benchmarks=intel_stress_ng --emon

  Refer to ./perfkitbenchmarker/data/emon/README.md for more details on flags and usage

"""

import functools
import logging
import os
import posixpath
import pdb

from perfkitbenchmarker import events, stages
from absl import flags
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import trace_util
from perfkitbenchmarker.linux_packages import emon

FLAGS = flags.FLAGS
flags.DEFINE_boolean('emon', False,
                     'Install and run emon on each of the system-under-test (SUT) including the client(s) machines')


class _EmonCollector(object):

  def _InstallEmon(self, vm):
    # calling into linux_packages.emon, either YumInstall or AptInstall
    # Do not Install Emon if trace_Skip_install is True and if EMON Dirs exist
    if FLAGS.trace_skip_install and emon.EmonDirsExist(vm):
      logging.info('Emon directories present...skipping Emon Installation')
      return
    vm.Install('emon')

  def Install(self, unused_sender, benchmark_spec):
    """Install emon

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(self._InstallEmon, vms)


  def Start(self, unused_sender, benchmark_spec):
    """Start running emon

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(emon.Start, vms)

  def After(self, unused_sender, benchmark_spec):
    """Stop emon, fetch results from VMs.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    vm_util.RunThreaded(emon.Stop, vms)
    emon_fetch_fns = [functools.partial(emon.FetchResults, vm) for vm in vms]
    vm_util.RunThreaded(lambda f: f(), emon_fetch_fns)
    emon_version = emon.GetEmonVersion(vms[0])
    edp_version = emon.GetEDPVersion(vms[0])
    benchmark_spec.software_config_metadata.update({'emon_version': emon_version,
                                                    'edp_version': edp_version})


  def Remove(self, unused_sender, benchmark_spec):
    """Stop emon, fetch results from VMs.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    if not FLAGS.trace_skip_cleanup:
      vm_util.RunThreaded(emon.EmonCleanup, vms)


def Register(parsed_flags):
  """Register the collector if FLAGS.emon is set."""
  if not parsed_flags.emon:
    return

  logging.info('Registering emon collector')
  collector = _EmonCollector()

  events.before_phase.connect(collector.Install, stages.RUN, weak=False)
  events.start_trace.connect(collector.Start, stages.RUN, weak=False)
  events.stop_trace.connect(collector.After, stages.RUN, weak=False)
  events.before_phase.connect(collector.Remove, stages.CLEANUP, weak=False)


def IsEnabled():
  return FLAGS.emon

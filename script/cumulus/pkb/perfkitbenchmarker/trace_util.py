from typing import List

import logging
import time

from perfkitbenchmarker import events, stages
from perfkitbenchmarker.virtual_machine import BaseVirtualMachine


def GetVMGroupNamesToTrace(benchmark_spec, group_names_string):
  group_names = []
  if not group_names_string:
    for group_name in benchmark_spec.vm_groups.keys():
      group_names.append(group_name)
  else:
    for group_name in group_names_string.split(','):
      if group_name in benchmark_spec.vm_groups:
        group_names.append(group_name.strip())
      else:
        logging.warn('unrecognized group name: {}'.format(group_name))
  return group_names


def GetVMGroupsToTrace(benchmark_spec, group_names_string):
  vm_groups = {}
  group_names = GetVMGroupNamesToTrace(benchmark_spec, group_names_string)
  for name in group_names:
    if name in benchmark_spec.vm_groups.keys():
      vm_groups[name] = benchmark_spec.vm_groups[name]
  return vm_groups


def GetVMsToTrace(benchmark_spec, group_names_string) -> List[BaseVirtualMachine]:
  """ Return list of vms from benchmark_spec that match group names specified
      in group_names_string as comma separated list. If group_names_string is
      empty, return all vms regardless of group.
  """
  vms = []
  for group_name in GetVMGroupNamesToTrace(benchmark_spec, group_names_string):
    if group_name in benchmark_spec.vm_groups:
      vms.extend(benchmark_spec.vm_groups[group_name])
  vms = list(set(vms))
  return vms


def ControlTracesByLogfileProcess(vm, benchmark_spec, logfile, start_phrase, stop_phrase=None, duration=None):
  """A function meant to be started as a separate process for monitoring a log file.
  Upon seeing a given start_phrase, will issue the start_trace event. Process will
  send the stop_trace event if provided a stop_phrase or duration.

  Args:
    vm: VM object where log file is being generated.
    benchmark_spec: benchmark_spec that will be send with the start/stop traces events.
    logfile: Full path to log file on VM that will be monitored for phrases.
    start_phrase: String pattern that will be passed to a grep command while tailing logfile to
      determine when to start traces.
    stop_phrase: Optional string pattern that will be passed to a grep command while tailing logfile to
      determine when to stop traces.
    duration: Duration in seconds to run traces if a specific time period is desired.
  """
  traces_started = False
  logging.info('Tailing {logfile} for start phrase \'{start_phrase}\''.format(logfile=logfile, start_phrase=start_phrase))
  _, _, retcode = vm.RemoteCommandWithReturnCode('tail --retry -f {logfile} | grep -q \'{start_phrase}\''.format(logfile=logfile, start_phrase=start_phrase))
  if retcode == 0:
    logging.info('Found start phrase \'{start_phrase}\' in {logfile}.'.format(logfile=logfile, start_phrase=start_phrase))
    events.start_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
    traces_started = True

  if traces_started:
    if stop_phrase:
      _, _, retcode = vm.RemoteCommandWithReturnCode("tail --retry -f {logfile} | grep -q '{stop_phrase}'".format(logfile=logfile, stop_phrase=stop_phrase))
      if retcode == 0:
        logging.info("Found stop phrase '{stop_phrase}' in {logfile}.".format(logfile=logfile, stop_phrase=stop_phrase))
      events.stop_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
    elif duration:
      logging.info("Sleeping for {duration} seconds while traces run.".format(duration=duration))
      time.sleep(duration)
      logging.info("Traces duration ended, stopping traces.")
      events.stop_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
    else:
      logging.warn("No log stop phrase or traces duration defined, traces will not be cleaned up by this process.")

import logging
import os
import time
from itertools import filterfalse

import requests
import posixpath
from typing import Set, List, Tuple

from absl import flags
from jsonlines import jsonlines
from pathlib import Path

from perfkitbenchmarker import events, trace_util, vm_util, data, stages
from perfkitbenchmarker.benchmark_spec import BenchmarkSpec
from perfkitbenchmarker.errors import Setup
from perfkitbenchmarker.linux_packages import INSTALL_DIR
from perfkitbenchmarker.virtual_machine import BaseVirtualMachine


# Cadvisor configuration constants
CADVISOR_DIR = posixpath.join(INSTALL_DIR, 'cAdvisor-metrics')

DEFAULT_PERF_CONFIG_SRC = posixpath.join(Path(os.path.dirname(os.path.realpath(__file__))).parent.absolute(), 'data', 'cAdvisor_metrics', "perf-default.json")
PERF_CONFIG_NAME = "perf-config.json"
CONTAINER_PERF_CONFIG_SRC = f"/cadvisor-config/{PERF_CONFIG_NAME}"
CADVISOR_CONTAINER_NAME = "cadvisor"
CADVISOR_PORT = 8080

# Prometheus configuration constants
PROMETHEUS_PORT = 9090
SCRAPE_INTERVAL = 5
MAX_NUM_OF_SAMPLES = 200
PROMETHEUS_YAML_CONFIG = 'cAdvisor_metrics/prometheus-config.yaml.j2'
PROMETHEUS_CONFIG_FILE_NAME = "prometheus.yml"

# Miscellaneous configuration constants
FIREWALL_PROTECTED_CSP = {"AWS", "Azure", "GCP"}
NETWORK_NAME = "cadvisor-metrics-net"


FLAGS = flags.FLAGS
flags.DEFINE_boolean(
    'cadvisor', False, 'Install and run cadvisor data collection on the target system.'
)
flags.DEFINE_string(
    'cadvisor_prometheus_group', None,
    'Point group with machine that will run Prometheus to collect metrics.'
)
flags.DEFINE_string(
    'perf_config_src', DEFAULT_PERF_CONFIG_SRC,
    'Absolute path to the perf configuration file.'
)


class CadvisorCollector(object):

  def __init__(self):
    self._start_tracing_epoch = None
    self._stop_tracing_epoch = None

  def Install(self, _, benchmark_spec: BenchmarkSpec):
    """
    Install Telemetry.

    Args:
      _: Unused parameter (unused_sender), that fits event connection "interface" (or signature)
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently running.
    """
    logging.info('Installing telemetry')
    observed_machines, metrics_collect_machine = self._get_tracing_associated_machines(
        benchmark_spec
    )

    machines_with_docker = observed_machines | {metrics_collect_machine}
    for machine in machines_with_docker:
      self._InstallDockerTelemetry(machine)
      self._StartDockerNetwork(machine)
      machine.RemoteCommand(f"mkdir -p {CADVISOR_DIR}")

    self._enablePrometheusFirewallAccess(metrics_collect_machine)

  def Start(self, _, benchmark_spec):
    """
    Start Telemetry

    Args:
      _: Unused parameter (unused_sender), that fits event connection "interface" (or signature)
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently running.
    """
    logging.info('Starting telemetry')
    observed_machines, metrics_collect_machine = self._get_tracing_associated_machines(
        benchmark_spec
    )

    observed_machines_addresses = []
    for machine in observed_machines:
      if machine == metrics_collect_machine:
        observed_machines_addresses.append(CADVISOR_CONTAINER_NAME)  # scrape the same machine
      else:
        observed_machines_addresses.append(machine.internal_ip or machine.ip_address)

    vm_util.RunThreaded(self._StartCAdvisorTelemetry, list(observed_machines))
    self._StartPrometheusTelemetry(metrics_collect_machine, observed_machines_addresses)

    self._start_tracing_epoch = time.time()

  def After(self, _, benchmark_spec):
    """
    Fetch results and stop telemetry

    Args:
      _: Unused parameter (unused_sender), that fits event connection "interface" (or signature)
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark currently running.
    """

    self._stop_tracing_epoch = time.time()
    self._FetchResults(benchmark_spec)
    self._StopTelemetry(benchmark_spec)

  def _StopTelemetry(self, benchmark_spec: BenchmarkSpec):
    """Stops Telemetry on the VMs."""
    logging.info('Stopping telemetry')

    observed_machines, metrics_collect_machine = self._get_tracing_associated_machines(
        benchmark_spec
    )

    vm_util.RunThreaded(self._StopPrometheusTelemetry, [metrics_collect_machine])
    vm_util.RunThreaded(self._StopCAdvisorTelemetry, list(observed_machines))

  def _FetchResults(self, benchmark_spec: BenchmarkSpec):
    """Fetches telemetry results."""

    observed_machines, prometheus_collector_machine = self._get_tracing_associated_machines(
        benchmark_spec
    )
    logging.info('Collect metrics from machines')

    for machine in observed_machines:
      logging.info(f'Collect metrics from machine {machine.name}')
      self.query_metrics(prometheus_collector_machine.ip_address, machine)

  @staticmethod
  def _InstallDockerTelemetry(vm):
    """Installs telemetry tools for cAdvisor metrics on VM."""
    logging.info('Installing docker environment')
    vm.Install('docker_ce')

  @staticmethod
  def _enablePrometheusFirewallAccess(vm: BaseVirtualMachine):
    """
    Adds firewall rule to allow external access to Prometheus.
    """
    if vm.CLOUD in FIREWALL_PROTECTED_CSP:
      logging.info(f"Open port {PROMETHEUS_PORT}")
      vm.firewall.AllowPort(vm, PROMETHEUS_PORT)

  @staticmethod
  def _StartDockerNetwork(vm):
    """Starts docker network for tracing."""
    vm.RemoteCommand(f"docker network create {NETWORK_NAME}")

  @staticmethod
  def _StartCAdvisorTelemetry(vm):
    """Starts telemetry tools for cAdvisor metrics on VM."""

    logging.debug("Send perf config to cAdvisor")
    perf_config_remote_path = posixpath.join(CADVISOR_DIR, PERF_CONFIG_NAME)
    vm.RemoteHostCopy(FLAGS.perf_config_src, perf_config_remote_path)
    logging.info(f"Perf configuration has been copied to cAdvisor machine {vm.ip_address}")

    logging.debug(f"Start telemetry with cAdvisor on machine {vm.ip_address}")
    vm.RemoteCommand(
        "sudo docker run "
        "-d "
        "--privileged "
        "--rm "
        "--volume=/:/rootfs:ro "
        "--volume=/var/run:/var/run:rw "
        "--volume=/sys:/sys:ro "
        "--volume=/var/lib/docker/:/var/lib/docker:ro "
        "--volume=/dev/disk/:/dev/disk:ro "
        f"--volume={perf_config_remote_path}:{CONTAINER_PERF_CONFIG_SRC}:ro "
        f"--publish={CADVISOR_PORT}:{CADVISOR_PORT} "
        f"--name={CADVISOR_CONTAINER_NAME} "
        f"--network {NETWORK_NAME} "
        "gcr.io/cadvisor/cadvisor:v0.40.0 "
        f"-perf_events_config={CONTAINER_PERF_CONFIG_SRC} "
        "--disable_metrics=accelerator,sched,process,disk,diskIO,hugetlb,resctrl,memory_numa,network,tcp,udp,referenced_memory,cpu_topology"
    )

  @staticmethod
  def _StartPrometheusTelemetry(vm, addresses: List[str]):
    """
    Starts Prometheus tool for collecting cAdvisor metrics.

    This function at first prepares configuration file for Prometheus. The config is based on the template.
    Then, the actual service is started.
    """

    logging.info(f"Start telemetry collection with Prometheus on machine {vm.ip_address}")

    addresses_with_ports = [f"{addr}:{CADVISOR_PORT}" for addr in addresses]
    context = {
        "targets_list": addresses_with_ports,
        "scrape_interval": SCRAPE_INTERVAL,
    }

    prometheus_config_local_path = data.ResourcePath(PROMETHEUS_YAML_CONFIG)
    prometheus_config_remote_path = posixpath.join(CADVISOR_DIR, PROMETHEUS_CONFIG_FILE_NAME)
    vm.RenderTemplate(prometheus_config_local_path, prometheus_config_remote_path, context=context)
    vm.RemoteCommand(f"chmod +r {prometheus_config_remote_path}")

    vm.RemoteCommand(
        "sudo docker run "
        "-d "
        "--rm "
        f"-v {prometheus_config_remote_path}:/etc/prometheus/prometheus.yml "
        "--publish=9090:9090 "
        f"--network {NETWORK_NAME} "
        "--name=prometheus "
        "prom/prometheus:v2.28.1"
    )

  @staticmethod
  def _StopCAdvisorTelemetry(vm):
    """Stops cAdvisor metrics collection on the VM."""
    logging.debug('Stopping cAdvisor telemetry')
    vm.RemoteCommand("sudo docker stop cadvisor")
    vm.RemoveFile(FLAGS.perf_config_src)

  @staticmethod
  def _StopPrometheusTelemetry(vm):
    """Stops Prometheus scraping on the VM."""
    logging.info('Stopping Prometheus telemetry')
    vm.RemoteCommand("sudo docker stop prometheus")

  @staticmethod
  def _RemoveDockerNetwork(vm):
    """Remove docker network for tracing."""
    logging.info(f'Removing Docker newtwork {NETWORK_NAME}')
    vm.RemoteCommand(f"docker network rm {NETWORK_NAME}")

  def _get_tracing_associated_machines(
      self, benchmark_spec: BenchmarkSpec
  ) -> Tuple[Set[BaseVirtualMachine], BaseVirtualMachine]:
    cadvisor_machines = self._get_observed_machines(benchmark_spec)
    prometheus_machine = self._get_metrics_collect_machine(benchmark_spec)
    return cadvisor_machines, prometheus_machine

  @staticmethod
  def _get_observed_machines(benchmark_spec: BenchmarkSpec) -> Set[BaseVirtualMachine]:
    """
    Get machines that will have cAdvisor installed.

    When workload has only one machine:
    Return the only one machine.

    When workload contains many machines:
    Take machines pointed out by --trace_vm_groups flag.
    """

    benchmark_groups = benchmark_spec.config.vm_groups
    group_names = None

    if len(benchmark_groups) == 1:
      group_names = list(benchmark_groups)[0]

    if len(benchmark_groups) > 1:
      group_names = FLAGS.trace_vm_groups  # If flag not given, will trace all VMs

    observed_machines = trace_util.GetVMsToTrace(benchmark_spec, group_names)
    observed_machines = set(observed_machines)
    return observed_machines

  @staticmethod
  def _get_metrics_collect_machine(benchmark_spec: BenchmarkSpec) -> BaseVirtualMachine:
    """
    Get machine that will have installed Prometheus for collecting metrics.

    When workload has only one machine:
    Return the only one machine.

    When workload contains many machines:
    Take machines pointed out by --trace_vm_groups flag.
    """

    benchmark_groups = benchmark_spec.config.vm_groups
    group_name = None

    if len(benchmark_groups) == 1:
      group_name = list(benchmark_groups)[0]

    if len(benchmark_groups) > 1:
      if not FLAGS.cadvisor_prometheus_group:
        raise Setup.InvalidFlagConfigurationError(
            "For multi-vm environments, you must select machine for Prometheus with --cadvisor_prometheus_group flag."
        )
      group_name = FLAGS.cadvisor_prometheus_group

    collector_machine = trace_util.GetVMsToTrace(benchmark_spec, group_name)[0]
    return collector_machine

  def query_metrics(self, prometheus_endpoint, vm):
    """ For given Prometheus URL and traced machine, get metrics and save as JSON. """

    metrics_list = ["cadvisor_container_perf_events_total", "cadvisor_container_perf_uncore_events_total"]

    results_path = os.path.join(vm_util.GetTempDir(), vm.name + '-cadvisor')
    cmd = ['mkdir', '-p', results_path]
    vm_util.IssueCommand(cmd)

    vm_url = vm.internal_ip or vm.ip_address
    if vm.ip_address == prometheus_endpoint:
      vm_url = CADVISOR_CONTAINER_NAME

    for metric_name in metrics_list:
      params = {
          "query": f'{metric_name}{{instance="{vm_url}:{CADVISOR_PORT}"}}',
          "start": self._start_tracing_epoch,
          "end": self._stop_tracing_epoch,
          "step": str(calculate_step(self._start_tracing_epoch, self._stop_tracing_epoch))
      }
      output_file_path = f"{vm.name}-{metric_name}-cadvisor.json"
      response = requests.get('http://' + prometheus_endpoint + f":{PROMETHEUS_PORT}" + "/api/v1/query_range", params=params)
      if response.status_code == 200:
        print(f'Writing {metric_name}')
        data = response.json()
        if (metric_name == 'cadvisor_container_perf_events_total'):
          group_core(data)
        elif (metric_name == 'cadvisor_container_perf_uncore_events_total'):
          group_uncore(data)
        data.update({'query_metric': metric_name})
        with jsonlines.open(os.path.join(results_path, output_file_path), mode='w') as writer:
          writer.write(data)
      else:
        print(f'{metric_name} query failed with code {response.status_code}')

  def Remove(self, unused_sender, benchmark_spec):
    """Remove Docker leftovers from VMs.

    Args:
      benchmark_spec: benchmark_spec.BenchmarkSpec. The benchmark that stopped
          running.
    """
    observed_machines, metrics_collect_machine = self._get_tracing_associated_machines(
        benchmark_spec
    )
    machines_with_docker = observed_machines | {metrics_collect_machine}
    vm_util.RunThreaded(self._RemoveDockerNetwork, list(machines_with_docker))


def Register(parsed_flags):
  """Register the collector if FLAGS.cadvisor is set."""
  if not parsed_flags.cadvisor:
    return
  logging.info('Registering telemetry collector - cAdvisor')
  telemetry_collector = CadvisorCollector()
  events.before_phase.connect(telemetry_collector.Install, stages.RUN, weak=False)
  events.start_trace.connect(telemetry_collector.Start, stages.RUN, weak=False)
  events.stop_trace.connect(telemetry_collector.After, stages.RUN, weak=False)
  events.after_phase.connect(telemetry_collector.Remove, stages.CLEANUP, weak=False)


def IsEnabled():
  return FLAGS.cadvisor


def _group_results(results: list, custom_metric_key) -> dict:
  """
  Helper function that groups `results` similar by `instance`, `event` and one additional metric.

  This function extracts part of common logic from `group_core()` and `group_uncore()` functions.
  Grouping is done with building a tree with values of the indices mentioned above. For every record
  with matching indices, timestamped record values are summed.
  """

  values = {}
  epochs = []

  for time_value in results[0]['values']:
    epochs.append(time_value[0])

  for record in results:
    instance = record['metric']['instance']
    event = record['metric']['event']
    custom_metric = record['metric'][custom_metric_key]

    if instance not in values:
      values[instance] = {}
    if event not in values[instance]:
      values[instance][event] = {}
    if custom_metric not in values[instance][event]:
      values[instance][event][custom_metric] = {}

    for time_val in epochs:
      if time_val not in values[instance][event][custom_metric]:
        values[instance][event][custom_metric][time_val] = 0

    for sample_record in record["values"]:
      sample_record_timestamp = sample_record[0]
      sample_record_value = sample_record[1]
      values[instance][event][custom_metric][sample_record_timestamp] += float(sample_record_value)

  return values


def group_core(traces_data):
  """
  Group data for core metrics.

  This function groups metrics by following indices:
  * `id`
  * 'event'
  * 'instance'
  * `cpu`

  When `id` belongs to {'/', '/system.slice'}, values of same indices are aggregated with SUM
  and saved with `id` equal to '/'. Otherwise the records are left unchanged.

  This function is based on WOS script.
  """

  _IDS_TO_GROUP = {"/", "/system.slice"}

  if traces_data == {}:
    logging.error("No core data collected, check cadvisor availability on target")
    return

  results = traces_data['data']['result']
  if len(results) == 0:
    logging.warning("No core data collected, check cadvisor availability on target")
    return

  filtered_results = list(filter(lambda result: result["metric"]["id"] in _IDS_TO_GROUP, results))
  values = _group_results(filtered_results, 'cpu')

  new_data = list(filterfalse(lambda result: result["metric"]["id"] in _IDS_TO_GROUP, results))
  for instance in values:
    for event in values[instance]:
      for cpu_num in values[instance][event]:
        new_data.append(
            {
                'metric': {
                    '__name__': 'cadvisor_container_perf_events_total',
                    'cpu': cpu_num,
                    'event': event,
                    'id': '/',
                    'instance': instance,
                    'job': 'cadvisor'
                },
                'values': [
                    [time_val, str(value)] for time_val, value in values[instance][event][cpu_num].items()
                ]
            }
        )
  traces_data['data']['result'] = new_data


def group_uncore(traces_data):
  """
  Groups data for uncore metrics.

  This function groups metrics by following indices:
  * `socket`
  * 'event'
  * 'instance'

  Grouping aggregates data with SUM across different values of `pmu` field, which is removed after grouping.

  This function is based on WOS script.
  """

  if traces_data == {}:
    logging.error("No core data collected, check cadvisor availability on target")
    return

  results = traces_data['data']['result']
  if len(results) == 0:
    logging.warning("No core data collected, check cadvisor availability on target")
    return

  values = _group_results(results, 'socket')

  new_data = []
  for instance in values:
    for event in values[instance]:
      for socket in values[instance][event]:
        new_data.append(
            {
                'metric': {
                    '__name__': 'cadvisor_container_perf_uncore_events_total',
                    'event': event,
                    'id': '/',
                    'instance': instance,
                    'job': 'cadvisor',
                    'socket': socket
                },
                'values': [
                    [time_val, str(value)] for time_val, value in values[instance][event][socket].items()
                ]
            }
        )

  traces_data['data']['result'] = new_data


def calculate_step(start, end) -> int:
  """
  Find calculation step in seconds so that number of samples doesn't exceed `MAX_NUM_OF_SAMPLES`.

  Number of samples is limited so as metric files doesn't become too large. If concerned about
  missing potential bottlenecks, consider return const value.
  """

  duration = end - start
  logging.info("test duration was: {}s".format(duration))

  if duration > SCRAPE_INTERVAL * MAX_NUM_OF_SAMPLES:
    step = int(duration / MAX_NUM_OF_SAMPLES)
    return step
  else:
    return SCRAPE_INTERVAL

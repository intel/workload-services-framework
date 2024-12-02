#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import sys
import logging
import time
import requests
# from copy import deepcopy
from requests.adapters import HTTPAdapter, Retry

class PrometheusMetric:
  """Fetch and storage  metric information
  """

  def __init__(self, metric_name: str, time_range: int, node_name, end_time: int, powerstat_prometheus_url: str, sum_average_value=False):
    self.name = metric_name
    self.time_range = time_range
    self.node_name = node_name
    self.value = 0.0
    self.timestamp = 0
    self.offset = end_time
    self.prometheus_url = powerstat_prometheus_url
    self._get_avg_value(sum_average_value=sum_average_value)

  def _get_avg_value(self, sum_average_value=False):
    """Calculate averange over time value of metric
    """
    query = f'avg_over_time({self.name}\u007bnode_name="{self.node_name}"\u007d[{self.time_range}ms]@{self.offset})'
    result = self._get_data_from_prom(query=query)

    self.timestamp = result[0]['value'][0]
    if sum_average_value:
      for c_result in result:
        self.value += float(c_result['value'][1])
    else:
      self.value = float(result[0]['value'][1])

  def _get_data_from_prom(self, query: str):
    """Make GET call to prometheus api
    """
    full_url = f"{self.prometheus_url}/api/v1/query?query={query}".replace("//api", "/api")
    logging.debug(f"Prometheus GET query {full_url}")
    retries = Retry(total=5, backoff_factor=1.0, status_forcelist=[500, 502, 503, 504])

    try:
      s = requests.Session()
      s.mount('http://', HTTPAdapter(max_retries=retries))
      response = s.get(full_url)
      if response.status_code != 200:
        print("No metrics data found for query:")
        print(full_url)
        raise SystemExit
    except Exception as e:
      print(f'Encountered exception {e}.')
      raise SystemExit

    try:
      data = response.json()
      logging.debug(f"Prometheus response {data}")
      result = data["data"]["result"]
      if not result:
        print("No metrics data result found.")
        print("Is metric", self.name, "available?")
        print("Check if the workload duration is long enough to obtain data.")
        raise SystemExit
    except Exception as e:
      print(f'Encountered exception {e}.')
      raise SystemExit

    return result

if __name__ == "__main__":
    time_range = str(sys.argv[1])
    end_time = str(sys.argv[2])
    node_names =  str(sys.argv[3]).replace('[', '').replace(']', '').replace("'", '').replace(',', '').split()
    prometheus_url = str(sys.argv[4])

    total_power = 0.0
    for node_name in node_names:
      avg_power_node = PrometheusMetric("ipmi_power_watts", time_range, node_name, end_time, prometheus_url)
      power_current =  PrometheusMetric("powerstat_package_current_power_consumption_watts", time_range, node_name, end_time, prometheus_url, True)
      power_tdp = PrometheusMetric("powerstat_package_thermal_design_power_watts", time_range, node_name, end_time, prometheus_url, True)

      headroom = 100 - (float(power_current.value) / float(power_tdp.value) * 100)
      total_power += float(avg_power_node.value)
      print("Average power per node" + "=" + avg_power_node.node_name, " (W): ", avg_power_node.value)
      print("Headroom" + "=" + power_current.node_name, " (%): ", headroom)

    print("Total power" + "=all", " (W): ", total_power)

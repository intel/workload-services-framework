#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import humanfriendly
import logging
import numpy as np
import re
import os

class PerformanceData:
  def __init__(self,sut):

    self.sut = sut
    # Regular expressions for retrieving metrics from output log files
    self.regex_sar_pct_mem_used = re.compile(r'\d{2}:\d{2}:\d{2}\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+.\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+.\d+)\s+(\d+)\s+(\d+)\s+(\d+)')
    self.regex_sar_avg_cpu = re.compile(r'Average:\s+[a-z]+\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)')
    self.regex_sar_avg_cpu_mhz = re.compile(r'\s+[a-z]+\s+(\d+[\.\,]\d+)')
    self.regex_dstat_disk_metrics = re.compile(r'\s*\d+[a-zA-Z]?\s+\d+[a-zA-Z]?\s*')
    self.regex_sar_cpu_line = re.compile(r'\s+[a-z]+\s+(\d{1,2}[\.\,]\d{1,2})\s+(\d{1,2}[\.\,]\d{1,2})\s+(\d{1,2}[\.\,]\d{1,2})\s+(\d{1,2}[\.\,]\d{1,2})\s+(\d{1,2}[\.\,]\d{1,2})\s+(\d{1,2}[\.\,]\d{1,2})')

  def GetMemoryUtilization(self, sar_output):
    """Get the memory used counter value from SAR output"""
    max_pct_mem_used = 0.0
    lines = []
    console_output = os.popen("cat {}".format(sar_output)).read().split("\n")

    for line in console_output:
      lines.extend(line.splitlines())

    for line in lines:
      result = self.regex_sar_pct_mem_used.search(line)
      if result:
        mem_used = float(result.group(4).replace(',','.'))
        if mem_used > max_pct_mem_used:
          max_pct_mem_used = mem_used

    logging.info("max_pct_mem_used = {}".format(max_pct_mem_used))
    return max_pct_mem_used

  def GetAverageCpuUtilization(self, sar_cpu_output):
    """Get the average CPU usage counter value from SAR output"""
    cpu_array = []
    with open(sar_cpu_output, 'r') as file:
        for line in file:
            result = self.regex_sar_cpu_line.search(line)
            if result:
                user_cpu = float(result.group(1).replace(',', '.'))
                nice_cpu = float(result.group(2).replace(',', '.'))
                system_cpu = float(result.group(3).replace(',', '.'))
                if user_cpu > 1.0 or nice_cpu > 1.0 or system_cpu > 1.0:
                    cpu_usage = user_cpu + nice_cpu + system_cpu
                    cpu_array.append(cpu_usage)
                    
    if len(cpu_array) > 1:
        mean = np.mean(cpu_array)
        std = np.std(cpu_array)
        cpu_usage = np.mean([x for x in cpu_array if x <= mean + std or x >= mean - std])
    
    logging.info("CPU Usage = {:.2f}".format(cpu_usage))  # added print statement for debugging
    return round(cpu_usage, 2)

  def GetAverageCpuFrequency(self, sar_cpu_mhz_output):
    """Get the average CPU frequency counter value from SAR output"""
    cpu_mhz = 0.0

    # On ARM64 platforms, the sar utility (sar -m CPU) does not work correctly
    # when getting cpu frequency. In some cases there is no output at all and
    # in other cases there is incorrect output and no summary
    if not self.sut.IsArm64Target():
      lines = []
      console_output = os.popen("cat {}".format(sar_cpu_mhz_output)).read().split("\n")

      for line in console_output:
        lines.extend(line.splitlines())
      frequency_array = []
      for line in lines:
        result = self.regex_sar_avg_cpu_mhz.search(line)
        if result:
          cpu_mhz = float(result.group(1).replace(',','.'))
          frequency_array.append(cpu_mhz)
      if len(frequency_array) > 1:
        mean = np.mean(frequency_array)
        std = np.std(frequency_array)
        cpu_mhz = np.mean([x for x in frequency_array if x < mean + std or x > mean - std])

    logging.info("CPU MHz = {:.2f}".format(cpu_mhz))
    return round(cpu_mhz,2)

  def GetDiskMetrics(self, dstat_output):
    """Get disk metrics from dstat output"""
    sum_active_read_bytes = 0
    sum_active_write_bytes = 0
    active_read_count = 0
    active_write_count = 0
    lines = []
    console_output = os.popen("cat {}".format(dstat_output)).read().split("\n")

    for line in console_output:
      lines.extend(line.splitlines())

    # Remove first non-zero entry from dstat as it's add invalid constant
    # to average active_reads and active_writes
    for line in lines:
      match = self.regex_dstat_disk_metrics.search(line)
      if match:
          lines.remove(line)
          break

    for line in lines:
      result = self.regex_dstat_disk_metrics.search(line)
      if result and 'missed' not in line:
        active_read = float(humanfriendly.parse_size((line.split())[0], binary=True))
        active_write = float(humanfriendly.parse_size((line.split())[1], binary=True))

        if active_read > 0:
          sum_active_read_bytes += active_read
          active_read_count += 1

        if active_write > 0:
          sum_active_write_bytes += active_write
          active_write_count += 1

    if active_read_count > 0:
      avg_active_read_bytes = sum_active_read_bytes / active_read_count
    else:
      avg_active_read_bytes = 0

    if active_write_count > 0:
      avg_active_write_bytes = sum_active_write_bytes / active_write_count
    else:
      avg_active_write_bytes = 0

    logging.info("avg_active_read_bytes = {}".format(avg_active_read_bytes))
    logging.info("avg_active_write_bytes = {}".format(avg_active_write_bytes))

    return (avg_active_read_bytes, avg_active_write_bytes)

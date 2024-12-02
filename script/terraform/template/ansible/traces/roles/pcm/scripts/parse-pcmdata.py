#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import json
import sys
from datetime import datetime
import os


min_time = 0
max_time = 0
base_time = int(sys.argv[2])*1000

def read_pcm_sensor_server_logs(logs_dir):
  global min_time, max_time, base_time
  pcm_data = []
  lines = []

  with open(os.path.join(logs_dir, "records.mjson")) as fd:
    for line in fd.readlines():
      lines.append(line)
      if line.startswith("}"):
        try:
          this_record = json.loads("\n".join(lines))
          lines = []
          interval = (this_record["Interval us"] - pcm_data[-1]["Interval us"])*1000 if pcm_data else 1000000000
          base_time = base_time + interval
          this_record["time"] = base_time
          if (min_time == 0) or (min_time > this_record["time"]):
            min_time = this_record["time"]
          if (max_time == 0) or (max_time < this_record["time"]):
            max_time = this_record["time"]
          pcm_data.append(this_record)
        except:
          break
  return pcm_data

def read_pcm_power_logs(logs_dir):
  global min_time, max_time, base_time
  pcm_data = []
  this_record = {}

  with open(os.path.join(logs_dir, "power.records")) as fd:
    for line in fd.readlines():
      if line.startswith("Time elapsed: "):
        if this_record:
          pcm_data.append(this_record)
          this_record = {}
        time_elapsed = float(line.split(" ")[2])
        base_time = base_time + int(time_elapsed)
        this_record["time"] = base_time
        if (min_time == 0) or (min_time > this_record["time"]):
          min_time = this_record["time"]
        if (max_time == 0) or (max_time < this_record["time"]):
          max_time = this_record["time"]

      if line.startswith("S") and "Consumed energy units:" in line:
        socket = "socket-" + (line[1:].split(";")[0])
        if socket not in this_record:
          this_record[socket] = {}
        this_record[socket]["energy"] = float(line.split(" ")[9].split(";")[0])

      if line.startswith("S") and "Consumed DRAM energy units:" in line:
        socket = "socket-" + (line[1:].split(";")[0])
        if socket not in this_record:
          this_record[socket] = {}
        this_record[socket]["dram-energy"] = float(line.split(":")[-1].strip())

  if this_record:
    pcm_data.append(this_record)
  return pcm_data
 
        
def print_power_series(pcm_data, title, key):
  print(f"const data_{title}_series=[")
  for s in range(len(pcm_data[0]["Sockets"])):
    print("{")
    print("  'name': 'socket-{}',".format(pcm_data[0]["Sockets"][s]["Socket ID"]))
    print("  'data': [")
    for i in range(len(pcm_data)):
      interval = (pcm_data[i]["time"] - pcm_data[i-1]["time"])/1000000000 if (i>1) else 1
      print("    [{}, {}],".format(pcm_data[i]["time"], pcm_data[i]["Sockets"][s]["Uncore"]["Uncore Counters"][key]/interval))
    print("  ]")
    print("},")
  print("{")
  print("  'name': 'aggregated',")
  print("  'data': [")
  for i in range(len(pcm_data)):
    interval = (pcm_data[i]["time"] - pcm_data[i-1]["time"])/1000000000 if (i>1) else 1
    print("    [{}, {}],".format(pcm_data[i]["time"], pcm_data[i]["Uncore Aggregate"]["Uncore Counters"][key]/interval))
  print("  ]")
  print("},")
  print("];")


def print_pcm_power_series(pcm_data, title, key):
  print(f"const data_{title}_series=[")
  for s in [k for k in pcm_data[0] if k.startswith("socket-")]:
    print("{")
    print(f"  'name': '{s}',")
    print("  'data': [")
    for i in range(len(pcm_data)):
      print("    [{}, {}],".format(pcm_data[i]["time"], pcm_data[i][s][key]))
    print("  ]")
    print("},")
  print("{")
  print("  'name': 'aggregated',")
  print("  'data': [")
  for i in range(len(pcm_data)):
    power_sum = 0
    for s in [k for k in pcm_data[0] if k.startswith("socket-")]:
      power_sum = power_sum + pcm_data[i][s][key]
    print("    [{}, {}],".format(pcm_data[i]["time"], power_sum))
  print("  ]")
  print("},")
  print("];")


action = sys.argv[1]

if action == "pcm-sensor-server":
  pcm_data = read_pcm_sensor_server_logs(sys.argv[3])
  if pcm_data:
    print_power_series(pcm_data, "socket_power", "Package Joules Consumed")
    print_power_series(pcm_data, "dram_socket_power", "DRAM Joules Consumed")
    print(f"const max_time={max_time}, min_time={min_time};")

if action == "pcm-power":
  pcm_data = read_pcm_power_logs(sys.argv[3])
  if pcm_data:
    print_pcm_power_series(pcm_data, "socket_power", "energy")
    print_pcm_power_series(pcm_data, "dram_socket_power", "dram-energy")
    print(f"const max_time={max_time}, min_time={min_time};")


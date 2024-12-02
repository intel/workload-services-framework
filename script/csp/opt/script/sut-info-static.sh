#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

remote_access () {
  if [ "$sut_host" = "@127.0.0.1" ]; then
      "$@" 2> /dev/null || true
  else
      ssh -p $sut_port $sut_host "$@" 2> /dev/null || true
  fi
}

for instance in $@; do
  vm_group="${instance//:*/}"
  sut_host="${instance//*:/}"
  sut_port="$(echo "$instance" | cut -f2 -d:)"
  sut_info="$(remote_access cat /proc/cpuinfo /proc/meminfo)"
  vcpus="$(echo "$sut_info" | grep -E '^processor\s*:' | wc -l)"
  memory="$(echo "$sut_info" | awk '/^MemTotal:/{print int($2/1024)}')"
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$memory"
  gpus=()
  IFS=$'\n' gpus+=($(remote_access nvidia-smi --query-gpu=gpu_name --format=csv,noheader | awk '{d[$0]++}END{for(n in d)print d[n]"x"n}'))
  IFS=$'\n' gpus+=($(remote_access hl-smi -Q name --format=csv,noheader | awk '{d["Habana Gaudi "$0]++}END{for(n in d)print d[n]"x"n}'))
  (IFS=,;echo "${vm_group^^}_ACCELS=\"${gpus[*]}\"")
done


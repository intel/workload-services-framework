#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

zone=$1
shift
resource=$1
shift

instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines="$(aliyun ecs DescribeInstanceTypes $(idx=1; for inst1 in ${instances[@]}; do echo --InstanceTypes.$idx=$inst1; idx=$(( idx + 1 )); done))"
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  vcpus="$(echo "$lines" | tac | sed -n "/\"InstanceTypeId\":\s*\"$instance\"/,/\"InstanceTypeId\":/{/\"CpuCoreCount\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  memory="$(echo "$lines" | sed -n "/\"InstanceTypeId\":\s*\"$instance\"/,/\"InstanceTypeId\":/{/\"MemorySize\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$(( memory * 1024 ))"
done

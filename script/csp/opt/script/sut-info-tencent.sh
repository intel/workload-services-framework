#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

zone=$1
shift
region=$(echo $zone | cut -f1-2 -d-)

instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines="$(tccli cvm DescribeInstanceTypeConfigs --region $region --output json)"
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  vcpus="$(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"CPU\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  memory="$(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"Memory\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$memory"
done

#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

zone=$1
shift
compartment=$1
shift
instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines=""
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  if [[ "$instance" = *".Flex-"* ]]; then
      vcpus="$(echo $instance | cut -f2 -d-)"
      memory="$(echo $instance | cut -f3 -d-)"
  else
      [ -n "$line" ] || lines="$(oci compute shape list --compartment-id $compartment --all)"
      vcpus="$(echo "$lines" | tac | sed -n "/\"shape\":\s*\"$instance\"/,/\"shape\":/{/\"ocpus\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
      memory="$(echo "$lines" | tac | sed -n "/\"shape\":\s*\"$instance\"/,/\"shape\":/{/\"memory-in-gbs\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  fi
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$(( memory * 1024 ))"
done

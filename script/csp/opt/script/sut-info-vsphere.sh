#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  vcpus="$(echo "$instance" | cut -f2 -d-)"
  memory="$(echo "$instance" | cut -f3 -d-)"
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$memory"
done


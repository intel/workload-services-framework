#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

for network in $(echo "virsh --connect qemu:///system net-list" | ssh $@ bash -l | sed -n '/^-------/,${/active/{s/^ *\([^ ]*\).*/\1/;p}}'); do
  while IFS= read line; do
    line="${line/*</<}"
    line="${line/>*/>}"
    if [[ "$line" = "<host "*">" ]] && [[ "$line" = *" name='$PREFIX-"* ]]; then
      echo "virsh --connect qemu:///system net-update $network delete ip-dhcp-host \"$line\""
    fi
  done < <(echo "virsh --connect qemu:///system net-dumpxml $network" | ssh $@ bash -l) | ssh $@ bash -l
done

sleep 5s

for instance in $(echo "virsh --connect qemu:///system list" | ssh $@ bash -l | grep -F "$PREFIX-" | sed 's/^.*\(wsf-[^ ]*\).*/\1/'); do
  echo "virsh --connect qemu:///system destroy $instance"
  echo "virsh --connect qemu:///system undefine $instance"
done | ssh $@ bash -l

for pool in $(echo "virsh --connect qemu:///system pool-list" | ssh $@ bash -l | grep -F "$PREFIX-" | sed 's/^.*\(wsf-[^ ]*\).*/\1/'); do
  echo "virsh --connect qemu:///system pool-destroy $pool"
  echo "virsh --connect qemu:///system pool-undefine $pool"
done | ssh $@ bash -l


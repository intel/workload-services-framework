#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

for network in $(echo "virsh net-list" | ssh $@ bash -l | sed -n '/^-------/,${/active/{s/^ *\([^ ]*\).*/\1/;p}}'); do
  while IFS= read line; do
    line="${line/*</<}"
    line="${line/>*/>}"
    if [[ "$line" = "<host "*">" ]] && [[ "$line" = *" name='$PREFIX-"* ]]; then
      echo "virsh net-update $network delete ip-dhcp-host \"$line\""
    fi
  done < <(echo "virsh net-dumpxml $network" | ssh $@ bash -l) | ssh $@ bash -l
done

sleep 5s

for instance in $(echo "virsh list" | ssh $@ bash -l | grep -F "$PREFIX-" | sed 's/^.*\(wsf-[^ ]*\).*/\1/'); do
  echo "virsh destroy $instance"
  echo "virsh undefine $instance"
done | ssh $@ bash -l

for pool in $(echo "virsh pool-list" | ssh $@ bash -l | grep -F "$PREFIX-" | sed 's/^.*\(wsf-[^ ]*\).*/\1/'); do
  echo "virsh pool-destroy $pool"
  echo "virsh pool-undefine $pool"
done | ssh $@ bash -l


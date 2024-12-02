#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

NETWORK="$1"
shift
MAC="$1"
shift
 
read_ip_script () {
cat << EOF1
  ip=""
  dev="\$(virsh --connect qemu:///system net-info $NETWORK | sed -n '/Bridge:/{s/.*: *//;p}')"
  while [ -z "\$ip" ]; do
    ip="\$(virsh --connect qemu:///system net-dhcp-leases $NETWORK | grep -iF $MAC | sed -n '/ipv4/{s|^.*ipv4 *\([0-9.]*\).*|\1|;p;q}')"
    [ -z "\$ip" ] || continue
    ip="\$(sudo arp-scan -I \$dev -N -l | grep -iF $MAC | head -n1 | sed 's/^\([0-9.]*\).*/\1/')"
  done
  echo "\$ip"
EOF1
}

cat << EOF2
{
  "ip": "$(read_ip_script | ssh $@ bash -l)"
}
EOF2



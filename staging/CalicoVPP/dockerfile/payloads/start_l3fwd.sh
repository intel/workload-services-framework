#!/bin/bash

is_memif=${is_memif:-true}
mtu=${mtu:-1500}
l3fwd_cores_start=${l3fwd_cores_start:-16}
core_nums=${core_nums:-1}

sed -i "s|main-core.*|main-core ${l3fwd_cores_start}|g" /etc/vpp/vpp.conf
sed -i "s|corelist-workers.*|corelist-workers $((l3fwd_cores_start + 1))-$((l3fwd_cores_start + core_nums))|g" /etc/vpp/vpp.conf
sed -i "s|rx-queues\s*[0-9]*|rx-queues ${core_nums}|g" /run/vpp/vppstartup.conf
sed -i "s|tx-queues\s*[0-9]*|tx-queues ${core_nums}|g" /run/vpp/vppstartup.conf

if [[ "$mtu" = "9000" ]] && [[ "$is_memif" = "true" ]]; then
    sed -i "s|default data-size.*|default data-size 10240|g" /etc/vpp/vpp.conf
    sed -i "s|buffer-size\s*[0-9]*|buffer-size 10240|g" /run/vpp/vppstartup.conf
fi

ifconfig eth0 mtu "$mtu"

vpp -c /etc/vpp/vpp.conf && sleep infinity

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ ! -e /usr/sbin/collectd ]; then
    sudo yum install -y collectd
fi

sudo systemctl stop collectd
(cat | sudo tee /etc/collectd.conf) <<EOF
Interval 10

LoadPlugin syslog
LoadPlugin cpu
LoadPlugin csv
LoadPlugin df
LoadPlugin disk
LoadPlugin entropy
LoadPlugin ethstat
LoadPlugin interface
LoadPlugin ipc
LoadPlugin irq
LoadPlugin load
LoadPlugin memory
LoadPlugin swap
LoadPlugin cpufreq
LoadPlugin "aggregation"

<Plugin cpu>
    ReportByCpu true
    ValuesPercentage false
</Plugin>
<Plugin df>
    # ignore rootfs; else, the root file-system would appear twice, causing
    # one of the updates to fail and spam the log
    FSType rootfs
    # ignore the usual virtual / temporary file-systems
    FSType sysfs
    FSType proc
    FSType devtmpfs
    FSType devpts
    FSType tmpfs
    FSType fusectl
    FSType cgroup
    IgnoreSelected true
</Plugin>
<Plugin csv>
    DataDir "{{ collectd_csv_path }}"
    StoreRates true
</Plugin>
<Plugin disk>
    Disk "/[hs]d[a-z][0-9]+?$/"
    Disk "/xvd[a-z][a-z0-9]+?$/"
    Disk "/vd[a-z]?$/"
    Disk "/nvme[0-9c]+n[0-9]+$/"
    IgnoreSelected false
    UseBSDName false
    UdevNameAttr "DEVNAME"
</Plugin>

<Plugin ethstat>
    # AWS: ens5, Azure: eth0, GCP: ens4, other: eno1
    Interface "/^eth[0-9]?$/"
    Interface "/^ens[0-9]?$/"
    Interface "/^eno[0-9]?$/"
    Interface "/^enp[0-5]s[0-9]?$/"
    Interface "/^bond[0-9]?$/"
    Interface "/^br[0-9]?$/"
    Map "rx_csum_offload_errors" "if_rx_errors" "checksum_offload"
    Map "multicast" "if_multicast"
    MappedOnly false
</Plugin>

<Plugin interface>
    Interface "/^eth/"
    Interface "/^ens/"
    Interface "/^enp/"
    Interface "/^eno/"
    Interface "/^bond/"
    Interface "/^br/"
    IgnoreSelected false
</Plugin>
<Plugin irq>
    Irq 7
    Irq 8
    Irq 9
    IgnoreSelected true
</Plugin>

<Plugin load>
    ReportRelative true
</Plugin>
<Plugin "aggregation">
  <Aggregation>
    Plugin "cpu"
    Type "cpu"
    GroupBy "Host"
    GroupBy "TypeInstance"
    CalculateAverage true
  </Aggregation>
</Plugin>
EOF



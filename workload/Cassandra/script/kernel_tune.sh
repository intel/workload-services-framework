#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -e
role=$1

if [ "$role" == "server" ]; then
    echo "Tuning server..."
    #mount host /sys and /proc
    mount -o rw,remount /sys
    mount -o rw,remount /proc

    #for disk	
    disks_conf_path_array=($(ls /sys/class/block/*/queue/read_ahead_kb |grep -v loop| awk -F 'read_ahead_kb' '{print $1}'))
    num=${#disks_conf_path_array[@]}
    for path in "${disks_conf_path_array[@]}"
    do
        echo none > "$path/scheduler"
        #Setting the "rotational" to "0" inform the system that the device is a non-rotational storage device, 
        #typically an SSD or NVMe SSD. This can help optimize certain I/O operations and improve performance 
        #based on the characteristics of non-rotational storage devices
	    echo 0 > "$path/rotational"
	    echo 8 > "$path/read_ahead_kb"
    done

    #set the maximum number of open file descriptors for a user, "ulimit -n" to check current value
    #command ulimit need flage '--privileged' when docker run to take effect on host
    ulimit -n 1000000
    ulimit -l unlimited
fi

if [ "$role" == "client" ]; then
    echo "Tuning client..."
fi

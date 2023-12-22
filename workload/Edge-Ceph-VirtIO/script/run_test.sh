#!/bin/bash -e
#set -x
# Start-up script in VM guestOS, when the guestOS bringup and stable, this script will be called.
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
source /etc/profile
export $(echo ${benchmark_options//"-D"/""} | tr -t ';' '\n')
export $(echo ${configuration_options//"-D"/""} | tr -t ';' '\n')
mkdir -p /logs
mkfifo /export-test-logs

# Pre-filled data to disks
if [ "$SKIP_PREFILL" = "0" ];then
    bash -x /opt/test/pre_filled.sh > /logs/pre_fill_$(date +"%m-%d-%y-%H-%M-%S").log
    echo "=== disk pre_filling is finished==="
fi

# Get system information
echo "---vm cpu info---" >> /logs/system_info.log
lscpu >> /logs/system_info.log
echo "---vm memory info---" >> /logs/system_info.log
cat /proc/meminfo >> /logs/system_info.log
echo "---vm block device---" >> /logs/system_info.log
lsblk >> /logs/system_info.log

# Record start date
date +"%m-%d-%y-%H-%M-%S" > /home/vm_ready.log

cd /home && tar cf /export-test-logs vm_ready.log
# Wait until vm ready to do fio
while [ ! -f /home/start_test ]; do
    sleep 1s
done

# Call the test script in VMs
echo "=== Start to run the test in VM==="
bash -x /opt/test/IO_test.sh ; echo $? > /logs/status

# Collect the system log
journalctl > /logs/system.log 2>&1

# Record benchmark finished time
date +"%m-%d-%y-%H-%M-%S" > /logs/benchmark_end.log

cd /logs && tar cf /export-test-logs status *.log
echo "=== Finish the test and data collection==="
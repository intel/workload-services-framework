#!/bin/bash -e
#set -x
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORK_DIR="/opt/test"
PREFILL_CONFIG_FILE="${WORK_DIR}/prefill.fio"
# TEST parameters for FIO are packed in benchmark_options and configuration_options and have been written to /etc/profile
source /etc/profile
export $(echo ${benchmark_options//"-D"/""} | tr -t ';' '\n')
export $(echo ${configuration_options//"-D"/""} | tr -t ';' '\n')
# Output the TEST parameters for disk pre-filled
echo "TEST_DATASET_SIZE=$TEST_DATASET_SIZE"
echo "TEST_CASE=$TEST_CASE"

# Disks are different for each test case
disk_a="vdc"
disk_b="vdd"
disk_c="vde"
vda_size=$(lsblk | grep -w "vda" | awk '{print $4}')
vdb_size=$(lsblk | grep -w "vdb" | awk '{print $4}')
vdc_size=$(lsblk | grep -w "vdc" | awk '{print $4}')
if [ $vda_size == $vdb_size -a $vdb_size == $vdc_size ]; then
    disk_a="vda"
    disk_b="vdb"
    disk_c="vdc"
fi

# Pre-fill the disks before real test
cat>>${PREFILL_CONFIG_FILE}<<EOF
[global]
name=pre-fill
ioengine=$TEST_IO_ENGINE
numjobs=1
thread=1
norandommap=1
gtod_reduce=0
iodepth=8
group_reporting
rw=write
size=$TEST_DATASET_SIZE
bs=16M
direct=1
EOF
cat>>${PREFILL_CONFIG_FILE}<<EOF
[job1]
filename=/dev/$disk_a

EOF
# For regular case ,vdisk count is 3
if [ "$VM_SCALING" != "1" ]; then
cat >> ${PREFILL_CONFIG_FILE} <<EOF
[jobs2]
filename=/dev/$disk_b

[jobs3]
filename=/dev/$disk_c
EOF
fi

date && fio ${PREFILL_CONFIG_FILE} && date 
sleep 60s
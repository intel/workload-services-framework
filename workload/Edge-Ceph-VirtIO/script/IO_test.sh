#!/bin/bash -e
#set -x
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORK_DIR=/opt/test

# TEST parameters for FIO are packed in benchmark_options and configuration_options and have been written to /etc/profile
source /etc/profile
export $(echo ${benchmark_options//"-D"/""} | tr -t ';' '\n')
export $(echo ${configuration_options//"-D"/""} | tr -t ';' '\n')
# Output the TEST parameters for FIO
echo "TEST_OPERATION=$TEST_OPERATION"
echo "TEST_IO_ENGINE=$TEST_IO_ENGINE"
echo "TEST_JOBS_NUM=$TEST_JOBS_NUM"
echo "TEST_IO_DEPTH=$TEST_IO_DEPTH"
echo "TEST_BLOCK_SIZE=$TEST_BLOCK_SIZE"
echo "TEST_RAMP_TIME=$TEST_RAMP_TIME"
echo "TEST_DURATION=$TEST_DURATION"

cd $WORK_DIR

disk_a="vda"
disk_b="vdb"
disk_c="vdc"
if [ "$TEST_CASE" = "virtIO" ];then
    disk_a="vdc"
    disk_b="vdd"
    disk_c="vde"
fi

if [ "$TEST_OPERATION" = "random_read" ];then
    RW=randread
elif [ "$TEST_OPERATION" = "random_write" ];then
    RW=randwrite
elif [ "$TEST_OPERATION" = "sequential_read" ];then
    RW=read
elif [ "$TEST_OPERATION" = "sequential_write" ];then
    RW=write
fi

if [ "$VM_SCALING" = "0" ];then
cat>>$TEST_OPERATION.fio<<EOF
[global]
ioengine=$TEST_IO_ENGINE
numjobs=$TEST_JOBS_NUM
thread=1
norandommap=1
gtod_reduce=0
iodepth=$TEST_IO_DEPTH
group_reporting
#cpus_allowed=$TEST_CPUS_ALLOWED
rw=$RW
size=$TEST_DATASET_SIZE
bs=$TEST_BLOCK_SIZE
direct=1
time_based
ramp_time=$TEST_RAMP_TIME
runtime=$TEST_DURATION
[job1]
filename=/dev/$disk_a

[jobs2]
filename=/dev/$disk_b

[jobs3]
filename=/dev/$disk_c
EOF
elif [ "$VM_SCALING" = "1" ];then
cat>>$TEST_OPERATION.fio<<EOF
[global]
ioengine=$TEST_IO_ENGINE
numjobs=$TEST_JOBS_NUM
thread=1
norandommap=1
gtod_reduce=0
iodepth=$TEST_IO_DEPTH
group_reporting
#cpus_allowed=$TEST_CPUS_ALLOWED
rw=$RW
size=$TEST_DATASET_SIZE
bs=$TEST_BLOCK_SIZE
direct=1
time_based
ramp_time=$TEST_RAMP_TIME
runtime=$TEST_DURATION
[job1]
filename=/dev/$disk_a
EOF
fi

echo $TEST_OPERATION

# Collect fio config file
cat $TEST_OPERATION.fio > /logs/fio_config.log

fio $TEST_OPERATION.fio  >/logs/${TEST_CASE}_${TEST_OPERATION}_$(date +"%m-%d-%y-%H-%M-%S").log

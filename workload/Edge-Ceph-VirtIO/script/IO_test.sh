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
TEST_CASE_COMP=${TEST_CASE_COMP:-0}
# Output the TEST parameters for FIO
echo "TEST_OPERATION=$TEST_OPERATION"
echo "TEST_IO_ENGINE=$TEST_IO_ENGINE"
echo "TEST_JOBS_NUM=$TEST_JOBS_NUM"
echo "TEST_IO_DEPTH=$TEST_IO_DEPTH"
echo "TEST_BLOCK_SIZE=$TEST_BLOCK_SIZE"
echo "TEST_RAMP_TIME=$TEST_RAMP_TIME"
echo "TEST_DURATION=$TEST_DURATION"

cd $WORK_DIR

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

if [[ "$TEST_OPERATION" =~ "random_read" ]];then
    RW=randread
elif [[ "$TEST_OPERATION" =~ "random_write" ]];then
    RW=randwrite
elif [[ "$TEST_OPERATION" =~ "sequential_read" ]];then
    RW=read
elif [[ "$TEST_OPERATION" =~ "sequential_write" ]];then
    RW=write
fi

# Define random mixrw case , read:write=70:30
mixrw=""
if [ "$RANDOM_MIXRW" = "1" ]; then
    RW="randrw"
    mixrw="rwmixread=${MIXRW_RATIO}"
fi

# Define limit IOPS/BW case
if [ "$LIMIT_KPI" = "1" ]; then
    rate="rate_iops=${FIO_BENCHMARK_RATE}"
fi

cat > "$TEST_OPERATION.fio" <<EOF
[global]
ioengine=$TEST_IO_ENGINE
numjobs=$TEST_JOBS_NUM
thread=1
norandommap=1
gtod_reduce=0
iodepth=$TEST_IO_DEPTH
group_reporting
rw=$RW
$mixrw
$rate
size=$TEST_DATASET_SIZE
bs=$TEST_BLOCK_SIZE
direct=1
time_based
ramp_time=$TEST_RAMP_TIME
runtime=$TEST_DURATION
EOF
if [ "$TEST_CASE_COMP" == "1" ]; then
cat >> "$TEST_OPERATION.fio" <<EOF
buffer_compress_percentage=80
refill_buffers
buffer_pattern=0xdeadbeef
EOF
fi
cat >> "$TEST_OPERATION.fio" <<EOF
[job1]
filename=/dev/$disk_a

EOF
# For regular case ,vdisk count is 3
if [ "$VM_SCALING" != "1" ]; then
cat >> "$TEST_OPERATION.fio" <<EOF
[jobs2]
filename=/dev/$disk_b

[jobs3]
filename=/dev/$disk_c
EOF
fi

echo $TEST_OPERATION

# Collect fio config file
cat $TEST_OPERATION.fio > /logs/fio_config.log

fio $TEST_OPERATION.fio  > /logs/${TEST_CASE}_${TEST_OPERATION}_$(date +"%m-%d-%y-%H-%M-%S").log


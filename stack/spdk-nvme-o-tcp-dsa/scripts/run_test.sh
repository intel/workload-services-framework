#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -x

# export all of the options for env deployment,packed in benchmark_options and configuration_options
export $(echo ${BENCHMARK_OPTIONS//"-D"/""} | tr -t ';' '\n')
export $(echo ${CONFIGURATION_OPTIONS//"-D"/""} | tr -t ';' '\n')

# IO test configuration_parameters
TEST_IO_ENGINE=${TEST_IO_ENGINE:-"libaio"}
TEST_DURATION=${TEST_DURATION:-240} # Unit: second
TEST_RAMP_TIME=${TEST_RAMP_TIME:-60} # Unit: second
TEST_IO_THREADS=${TEST_IO_THREADS:-16} # IO threads for benchmark
TEST_BLOCK_SIZE=${TEST_BLOCK_SIZE:-4} # Unit: k bytes
TEST_DATASET_SIZE=${TEST_DATASET_SIZE:-"10240"}  # Unit: MiB
TEST_IO_DEPTH=${TEST_IO_DEPTH:-64}
TEST_JOBS_NUM=${TEST_JOBS_NUM:-10}  # Jobs or thread or cosbench drive nums on each node
TEST_CPUS_ALLOWED=${TEST_CPUS_ALLOWED:-"8-17"}  # cpu core invovled.
CPUS_ALLOWED_POLICY=${CPUS_ALLOWED_POLICY:-"split"}
TEST_CPUCORE_COUNT=${TEST_CPUCORE_COUNT:-4} # default use 4 cores.
TEST_OPERATION=${TEST_OPERATION:-"random_read"}  # read/write/randread/randwrite
RWMIX_READ=${RWMIX_READ:-70} # 70%, Read ratio,
RWMIX_WRITE=${RWMIX_WRITE:-30} # 30% Write ratio

TEST_RW_OPERATION=${TEST_RW_OPERATION:-"read"}
TEST_RW_OPERATION_MODE=${TEST_RW_OPERATION_MODE:-"rand"}

# For NVMe o TCP connection
TGT_TYPE=${TGT_TYPE:-"tcp"} # target is over tcp
TGT_ADDR=${TGT_ADDR:-"192.168.88.100"} # define the nvme-over-tcp tagert address, for TCP it's IP address.
TGT_SERVICE_ID=${TGT_SERVICE_ID:-"4420"} # for TCP, it's network IP PORT.
TGT_NQN=${TGT_NQN:-"nqn.2023-03.io.spdk:cnode"} # target nqn ID/name for discovery and connection.
ENABLE_DIGEST=${ENABLE_DIGEST:-"0"} # enable or not TCP transport digest

DRIVE_NUM=${DRIVE_NUM:-"1"}
drive_list=()

BASE_PATH=/opt
WORK_PATH=${BASE_PATH}/spdk
LOG_PATH=${BASE_PATH}/logs

# For NVMe over fabric tagert discovery and connecton
# nvme discover  -t tcp  -a 10.67.116.242 -s 4420
# nvme connect -t tcp -n "nqn.2023-03.io.spdk:cnode1" -a 10.67.116.242 -s 4420

function clean_up_env() {
    echo "Disconnect all of the drive: [${drive_list[@]} ]"

    for nvmef_cdev in ${drive_list[@]}; do
        # nvmef_cdev="/dev/$cdev"
        echo "Disconnect drive: $nvmef_cdev"
        nvme disconnect -d $nvmef_cdev
        sleep 1s
    done
}

function handle_exception() {
    echo "*** Error code $1 ***"
    clean_up_env
    exit -1
}

# function for exception
function exception_func() {
	trap - ERR SIGINT SIGTERM EXIT;
	echo "Exception occurs with status $? at line[$1]"
	clean_up_env
	exit -1
}

# 1. discover the target

nvme discover -t ${TGT_TYPE} -a ${TGT_ADDR} -s ${TGT_SERVICE_ID}
#TODO: wait for ready and detect the target log entry
sleep 5s

# 2. connect the target if find.

## for PDU digest, enable HDGST and DDGST
OPTIONS=""
if [ "$ENABLE_DIGEST" == "1" ]; then
    echo "Enable Disgest for PDU header and data"
    OPTIONS="-g -G"
fi

trap 'exception_func ${LINENO}' ERR SIGINT SIGTERM EXIT;

for i in $(seq 1 ${DRIVE_NUM}); do

    NQN=${TGT_NQN}${i}

    connection="$( nvme connect -t ${TGT_TYPE} -n ${NQN} -a ${TGT_ADDR} -s ${TGT_SERVICE_ID} ${OPTIONS} -o normal 2>&1)"
    error_code=$?
    if [[ "$connection" =~ "Failed" ]]; then
        echo "Failed connect the target[$i]: ${TGT_ADDR}:${TGT_SERVICE_ID} with ${NQN}"
        echo "Error: [${connection}]"
        handle_exception $error_code
    else
        echo "Connected to target ${TGT_ADDR}:${TGT_SERVICE_ID} with ${NQN}"
        echo "$connection"
        nvmef_cdev="/dev/$(echo $connection | awk '{print $2}')"
        drive_list[$((i-1))]=$nvmef_cdev
        nvmef_dev="$nvmef_cdev""n1"
        echo "Created local nvme drive: ${nvmef_cdev}"
    fi
    sleep 2s
done

sleep 5s

# 3. check nvme drive(s) TODO:
lsblk

# 4. Generate the fio config file for benchmark.
# Output the TEST parameters for FIO
echo "TEST_OPERATION=$TEST_OPERATION"
echo "TEST_IO_ENGINE=$TEST_IO_ENGINE"
echo "TEST_JOBS_NUM=$TEST_JOBS_NUM"
echo "TEST_IO_DEPTH=$TEST_IO_DEPTH"
echo "TEST_BLOCK_SIZE=$TEST_BLOCK_SIZE k"
echo "TEST_RAMP_TIME=$TEST_RAMP_TIME"
echo "TEST_DURATION=$TEST_DURATION"

cd $BASE_PATH

#  read   Sequential reads.
#  write  Sequential writes.
#  randread		Random reads.
#  randwrite    Random writes.
#  rw,readwrite Sequential mixed reads and writes.
#  randrw       Random mixed reads and writes.
if [[ ${TEST_RW_OPERATION_MODE} == "sequential" ]]; then
    FIO_RW=${TEST_RW_OPERATION}

    if [[ ${TEST_RW_OPERATION} == "mixedrw" ]]; then
        FIO_RW="rw,readwrite"
    fi
else # random
    FIO_RW="rand${TEST_RW_OPERATION}"

    if [[ ${TEST_RW_OPERATION} == "mixedrw" ]]; then
        FIO_RW="randrw"
    fi
fi

if [[ ${TEST_RW_OPERATION} == "mixedrw" ]]; then
    RW_MIXED="rwmixread=${TEST_RWMIX_READ} rwmixwrite=${TEST_RWMIX_WRITE}"
else
    RW_MIXED=""
fi

echo "Start the benchmark operation ${TEST_OPERATION}, RW=${FIO_RW}"
FIO_CONFIG_FILE="${TEST_OPERATION}_${TEST_BLOCK_SIZE}k"
cat>>$FIO_CONFIG_FILE.fio<<EOF
[global]
ioengine=$TEST_IO_ENGINE
numjobs=$TEST_JOBS_NUM
thread=1
norandommap=1
gtod_reduce=0
iodepth=$TEST_IO_DEPTH
group_reporting
cpus_allowed=$TEST_CPUS_ALLOWED
cpus_allowed_policy=$CPUS_ALLOWED_POLICY
rw=$FIO_RW
EOF
if [[ ${RW_MIXED} != "" ]]; then
cat >> $FIO_CONFIG_FILE.fio<<EOF
${RW_MIXED}
EOF
fi
cat >>$FIO_CONFIG_FILE.fio<<EOF
size=${TEST_DATASET_SIZE}M
bs=${TEST_BLOCK_SIZE}k
direct=1
time_based
ramp_time=$TEST_RAMP_TIME
runtime=$TEST_DURATION
EOF
i=1
for nvmef_cdev in ${drive_list[@]}; do

    nvmef_dev="$nvmef_cdev""n1"
    cat >>$FIO_CONFIG_FILE.fio<<EOF
[job$i]
filename=$nvmef_dev

EOF

    i=$((i+1))
done

# Collect fio config file
cat $FIO_CONFIG_FILE.fio > ${LOG_PATH}/${FIO_CONFIG_FILE}_fio_config.log

# ROI: Benchmark start flag for emon data collection
echo "Start benchmark"

fio $FIO_CONFIG_FILE.fio  >${LOG_PATH}/${FIO_CONFIG_FILE}_$(date +"%m-%d-%y-%H-%M-%S").log

# ROI: Benchmark end flag for emon data collection
echo "Finish benchmark"

echo " == Finished the benchmark and disconnect the target =="

trap - ERR SIGINT SIGTERM EXIT;

# 5. Cleanup
clean_up_env

echo "== End of the test =="

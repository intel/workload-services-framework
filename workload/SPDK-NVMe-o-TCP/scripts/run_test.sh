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

export TGT_ADDR_ARRAY=( $( echo ${TGT_ADDR} | tr -t ',' ' ' ) )  #(20.0.0.1,20.0.1.1,10.0.0.1,10.0.1.1) -> (20.0.0.1 20.0.1.1 10.0.0.1 10.0.1.1)
TGT_ADDR_NUM=${#TGT_ADDR_ARRAY[@]}  # the IP address count for TCP connection

DRIVE_NUM=${DRIVE_NUM:-"1"}
drive_list=()

BASE_PATH=/opt
WORK_PATH=${BASE_PATH}/spdk
LOG_PATH=${BASE_PATH}/logs

# For NVMe over fabric tagert discovery and connecton 
# nvme discover  -t tcp  -a 10.67.116.242 -s 4420
# nvme connect -t tcp -n "nqn.2023-03.io.spdk:cnode1" -a 10.67.116.242 -s 4420

function collect_target_data () {
    kubectl -n $CLUSTER_NS logs deployments.apps/spdk-nvme-o-tcp > ${LOG_PATH}/spdk-nvme-o-tcp-target-full.log
    kubectl -n $CLUSTER_NS describe deployments.apps/spdk-nvme-o-tcp > ${LOG_PATH}/spdk-nvme-o-tcp-target-des.log
    sleep 2s
    kubectl -n $CLUSTER_NS exec -it deployments.apps/spdk-nvme-o-tcp -- touch /cleanup
    sleep 10s
}

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

function wait_for_pods_ready () {
    until kubectl --namespace=$CLUSTER_NS wait pod --all --for=condition=Ready --timeout=1s 1>/dev/null 2>&1; do
        if kubectl --namespace=$CLUSTER_NS get pod -o json | grep -q Unschedulable; then
            echo "Error!!! One of the PODs is unschedulable..."
            return 3
        fi
    done
    return 0
}

function wait_for_spdk_target_ready () {
    until kubectl -n $CLUSTER_NS logs deployments.apps/spdk-nvme-o-tcp | less | grep "ready for test" 1>/dev/null 2>&1; do
        echo "Waiting for target ready..."
        sleep 5
    done

    kubectl -n $CLUSTER_NS logs deployments.apps/spdk-nvme-o-tcp > ${LOG_PATH}/spdk-nvme-o-tcp-target-init.log
    return 0
}

# Wait for the Target pod become ready.
# wait until either resource is ready or unschedulable
export -pf wait_for_pods_ready wait_for_spdk_target_ready
timeout 300s bash -c wait_for_pods_ready
timeout 600s bash -c wait_for_spdk_target_ready

# 1. discover the target 

#IP_LIST=$TGT_ADDR_ARRAY
#IP_list=(20.0.0.1 20.0.1.1 10.0.0.1 10.0.1.1)
IP_INDEX=1
for TGT_ADDR in ${TGT_ADDR_ARRAY[@]}; do
    nvme discover -t ${TGT_TYPE} -a ${TGT_ADDR} -s ${TGT_SERVICE_ID} 2>/dev/null
    sleep 1
    #TODO: wait for ready and detect the target log entry
done
sleep 5s

# 2. connect the target if find.

## for PDU digest, enable HDGST and DDGST
OPTIONS=""
if [ "$ENABLE_DIGEST" == "1" ]; then
    echo "Enable Disgest for PDU header and data"
    OPTIONS="-g -G"
fi

trap 'exception_func ${LINENO}' ERR SIGINT SIGTERM EXIT;

if [[ $DRIVE_NUM -lt $TGT_ADDR_NUM ]]; then
    echo "WARNING: No enough drive[$DRIVE_NUM] for multiple IP[$TGT_ADDR_NUM]!"
    # for single NIC use case
    echo "Connect to first IP..."
    TGT_ADDR=${TGT_ADDR_ARRAY[0]}

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

else
    # for multiple IP connection
    i=1  # for nqn/drive index
    #IP_LIST=$TGT_ADDR_ARRAY
    #IP_list=(20.0.0.1 20.0.1.1 10.0.0.1 10.0.1.1)
    IP_INDEX=0
    for TGT_ADDR in ${TGT_ADDR_ARRAY[@]}; do

        DRIVE_MOUNT=$(($DRIVE_NUM/$TGT_ADDR_NUM))
        LEFT_DRIVE=$(($DRIVE_NUM-$DRIVE_MOUNT*$IP_INDEX))
        if [ $LEFT_DRIVE -le 0 ]; then
            echo "WARNING: No enough drive[$LEFT_DRIVE]!"
            break
        fi

        if [ $LEFT_DRIVE -le $DRIVE_MOUNT ]; then
            DRIVE_MOUNT=$LEFT_DRIVE
        fi

        # connect nvme over tcp.
        for j in $(seq 1 ${DRIVE_MOUNT}); do

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
                i=$(($i + 1))
            fi
            sleep 2s
        done


	IP_INDEX=$((IP_INDEX + 1))
    done
fi


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


# 6. collect the target logs
collect_target_data

echo "== End of the test =="

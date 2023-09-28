#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORKLOAD=${WORKLOAD:-"spdk_nvme_o_tcp"}
TESTCASE_OPT=${1:-"gated"}

BENCHMARK_CLIENT_NODES=${BENCHMARK_CLIENT_NODES:-1} # Initiator count for benchmark.

# Fio parameters
TEST_DURATION=${TEST_DURATION:-600} # Unit: second
TEST_RAMP_TIME=${TEST_RAMP_TIME:-300} # Unit: second
TEST_IO_THREADS=${TEST_IO_THREADS:-16} # IO threads for benchmark
TEST_BLOCK_SIZE=${TEST_BLOCK_SIZE:-4} #Unit: k bytes
TEST_DATASET_SIZE=${TEST_DATASET_SIZE:-"10240"}  # Unit: MiB
TEST_IO_DEPTH=${TEST_IO_DEPTH:-32}
TEST_JOBS_NUM=${TEST_JOBS_NUM:-2}  # Jobs or thread or cosbench drive nums on each node
CPUS_ALLOWED=${CPUS_ALLOWED:-"0-31"}  # cpu core invovled.
CPUS_ALLOWED_POLICY=${CPUS_ALLOWED_POLICY:-"split"}
TEST_CPUCORE_COUNT=${TEST_CPUCORE_COUNT:-4} # default use 4 cores.
TEST_OPERATION=${TEST_OPERATION:-"sequential_read"}  # read/write/randread/randwrite
RWMIX_READ=${RWMIX_READ:-70} # 70%, Read ratio,
RWMIX_WRITE=${RWMIX_WRITE:-30} # 30% Write ratio 
TEST_IO_ENGINE=${TEST_IO_ENGINE:-"libaio"} # used for fio benchmark.

# For SPDK process
SPDK_PRO_CPUMASK=${SPDK_PRO_CPUMASK:-"0x3F"}
SPDK_PRO_CPUCORE=${SPDK_PRO_CPUCORE:-"1"} # cpu core count will be used
SPDK_HUGEMEM=${SPDK_HUGEMEM:-"8192"} # MiB
BDEV_TYPE=${BDEV_TYPE:-"drive"} # "mem" is for memory bdev for test, "drive" is using nvme drive for test.
DRIVE_PREFIX=${DRIVE_PREFIX:-"Nvme"}  # it's NVMe if we consider more drives. currently set to Nvme0
NVMeF_NS=""
NVMeF_NSID="1"
NVMeF_SUBSYS_SN="SPDKTGT001" # just hardcode for S/N

DRIVE_NUM=${DRIVE_NUM:-"1"}

# For debug
SPDK_TRACE=${SPDK_TRACE:-"0"}

# For NVMe o TCP connection
TGT_TYPE=${TGT_TYPE:-"tcp"} # target is over tcp
TGT_ADDR=${TGT_ADDR:-"192.168.88.100"} # define the nvme-over-tcp tagert address, for TCP it's IP address.
# TGT_ADDR="192.168.88.100,192.168.99.100" # define a set of target address if needed, add ',' between IPs
TGT_SERVICE_ID=${TGT_SERVICE_ID:-"4420"} # for TCP, it's network IP PORT.
TGT_NQN=${TGT_NQN:-"nqn.2023-03.io.spdk:cnode"} # target nqn ID/name for discovery and connection.
ENABLE_DIGEST=${ENABLE_DIGEST:-"0"} # enable or not TCP transport digest

# For NVMF TCP Transport configuration.
TP_IO_UNIT_SIZE=${TP_IO_UNIT_SIZE:-"131072"} #IO_UNIT_SIZE for create nvme over fabric transport, I/O unit size (bytes)
TP_MAX_QUEUE_DEPTH=${TP_MAX_QUEUE_DEPTH:-"128"}
TP_MAX_IO_QPAIRS_PER_CTRLR=${TP_MAX_IO_QPAIRS_PER_CTRLR:-"127"}
TP_IN_CAPSULE_DATA_SIZE=${TP_IN_CAPSULE_DATA_SIZE:-"4096"}
TP_MAX_IO_SIZE=${TP_MAX_IO_SIZE:-"131072"}
TP_NUM_SHARED_BUFFERS=${TP_NUM_SHARED_BUFFERS:-"8192"}
TP_BUF_CACHE_SIZE=${TP_BUF_CACHE_SIZE:-"32"}
TP_C2H_SUCCESS=${TP_C2H_SUCCESS:-"1"} # Add C2H success flag (or not) for data transfer, it's a optimization flag
TCP_TP_SOCK_PRIORITY=${TCP_TP_SOCK_PRIORITY:-"0"}

# Special config
ENABLE_DSA=${ENABLE_DSA:-"0"} # enable or disable DSA hero feature for IA paltform.

# Set the debug mode for workload
# 0 - disable debug mode
# 1 - debug the benchmark workload, deploy workload pod with doing nothing.
DEBUG_MODE="0"

TEST_CASE="$(echo ${TESTCASE_OPT} | cut -d_ -f1)" #withDSA/noDSA
TEST_RW_OPERATION_MODE="$(echo ${TESTCASE_OPT} | cut -d_ -f2)"  # sequential/random
TEST_RW_OPERATION="$(echo ${TESTCASE_OPT} | cut -d_ -f3)"   #read/write
TEST_OPERATION=${TEST_RW_OPERATION_MODE}_${TEST_RW_OPERATION}

if [ "$TESTCASE_OPT" == "gated" ]; then
    TEST_CASE="gated";
    TEST_DURATION=60;
    TEST_IO_THREADS=8
    CPUS_ALLOWED="8-9"
    BENCHMARK_CLIENT_NODES=1 # Gated case only has 1 benchmark pod.
    TEST_RW_OPERATION_MODE="random"
    TEST_RW_OPERATION="read"
    TEST_OPERATION="random_read"
fi

if [[ "${TEST_CASE}" == "withDSA" ]];then
   ENABLE_DSA=1
fi

if [ "$TEST_RW_OPERATION_MODE" == "random" ];then
    TEST_IO_DEPTH=64
    TEST_BLOCK_SIZE=64
elif [ "$TEST_RW_OPERATION_MODE" == "sequential" ];then
    TEST_IO_DEPTH=1024
    TEST_BLOCK_SIZE=1024 #1M
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"


# Set parameters for benchmark, pass through to benchmark operator with one parameter "BENCHMARK_OPTIONS".
BENCHMARK_OPTIONS="-DDEBUG_MODE=$DEBUG_MODE;\
-DTEST_DURATION=$TEST_DURATION;\
-DTEST_IO_THREADS=$TEST_IO_THREADS;\
-DTEST_BLOCK_SIZE=$TEST_BLOCK_SIZE;\
-DTEST_DATASET_SIZE=$TEST_DATASET_SIZE;\
-DTEST_IO_DEPTH=$TEST_IO_DEPTH;\
-DTEST_JOBS_NUM=$TEST_JOBS_NUM;\
-DTEST_CPUS_ALLOWED=$CPUS_ALLOWED;\
-DTEST_CPUS_ALLOWED_POLICY=$CPUS_ALLOWED_POLICY;\
-DTEST_CPUCORE_COUNT=$TEST_CPUCORE_COUNT;\
-DTEST_OPERATION=$TEST_OPERATION;\
-DTEST_RWMIX_READ=$RWMIX_READ;\
-DTEST_RWMIX_WRITE=$RWMIX_WRITE;\
-DTEST_RW_OPERATION_MODE=$TEST_RW_OPERATION_MODE;\
-DTEST_RW_OPERATION=$TEST_RW_OPERATION;\
-DTEST_RAMP_TIME=$TEST_RAMP_TIME;\
-DTEST_IO_ENGINE=$TEST_IO_ENGINE"

# Set the configuration options for environment and workload setup. pass through with one parmeter to workload.
CONFIGURATION_OPTIONS="-DBENCHMARK_CLIENT_NODES=$BENCHMARK_CLIENT_NODES;\
-DDEBUG_MODE=$DEBUG_MODE;\
-DSPDK_HUGEMEM=$SPDK_HUGEMEM;\
-DTEST_CASE=$TEST_CASE;\
-DSPDK_PRO_CPUMASK=$SPDK_PRO_CPUMASK;\
-DSPDK_PRO_CPUCORE=$SPDK_PRO_CPUCORE;\
-DBDEV_TYPE=$BDEV_TYPE;\
-DDRIVE_PREFIX=$DRIVE_PREFIX;\
-DNVMeF_NS=$NVMeF_NS;\
-DNVMeF_NSID=$NVMeF_NSID;\
-DNVMeF_SUBSYS_SN=$NVMeF_SUBSYS_SN;\
-DTGT_TYPE=$TGT_TYPE;\
-DTGT_ADDR=$TGT_ADDR;\
-DTGT_SERVICE_ID=$TGT_SERVICE_ID;\
-DTGT_NQN=$TGT_NQN;\
-DENABLE_DIGEST=$ENABLE_DIGEST;\
-DTP_IO_UNIT_SIZE=$TP_IO_UNIT_SIZE;\
-DENABLE_DIGEST=$ENABLE_DIGEST;\
-DDRIVE_NUM=$DRIVE_NUM;\
-DENABLE_DSA=$ENABLE_DSA;\
-DTP_MAX_QUEUE_DEPTH=$TP_MAX_QUEUE_DEPTH;\
-DTP_MAX_IO_QPAIRS_PER_CTRLR=$TP_MAX_IO_QPAIRS_PER_CTRLR;\
-DTP_IN_CAPSULE_DATA_SIZE=$TP_IN_CAPSULE_DATA_SIZE;\
-DTP_MAX_IO_SIZE=$TP_MAX_IO_SIZE;\
-DTP_NUM_SHARED_BUFFERS=$TP_NUM_SHARED_BUFFERS;\
-DTP_BUF_CACHE_SIZE=$TP_BUF_CACHE_SIZE;\
-DTP_C2H_SUCCESS=$TP_C2H_SUCCESS;\
-DTCP_TP_SOCK_PRIORITY=$TCP_TP_SOCK_PRIORITY;\
-DSPDK_TRACE=$SPDK_TRACE;"


# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
BENCH_STACK_NAME="spdk-nvme-o-tcp"
BENCH_JOB_NAME="spdk-nvme-o-tcp-fio"
JOB_FILTER="app=${BENCH_JOB_NAME}"

RECONFIG_OPTIONS=" -DTEST_CASE=$TEST_CASE \
-DBENCH_STACK_NAME=$BENCH_STACK_NAME \
-DBENCH_JOB_NAME=$BENCH_JOB_NAME \
-DDEBUG_MODE=$DEBUG_MODE \
-DSPDK_HUGEMEM=$SPDK_HUGEMEM \
-DBENCH_OPERATOR_NAME=$BENCH_OPERATOR_NAME \
-DBENCHMARK_OPTIONS=$BENCHMARK_OPTIONS \
-DCONFIGURATION_OPTIONS=$CONFIGURATION_OPTIONS "

# Workload Setting
WORKLOAD_PARAMS=(TEST_CASE \
DEBUG_MODE \
SPDK_HUGEMEM \
BENCH_OPERATOR_NAME \
BENCHMARK_OPTIONS \
CONFIGURATION_OPTIONS \
)

# Script Setting
SCRIPT_ARGS="$TEST_OPERATION"

# Emon Test Setting
EVENT_TRACE_PARAMS="roi,Start benchmark,Finish benchmark"

TIMEOUT=${TIMEOUT:-3000}
. "$DIR/../../script/validate.sh"
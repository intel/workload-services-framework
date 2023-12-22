#!/bin/bash -e
#set -x
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-"edge_ceph_virtio"}
TESTCASE_OPT=${1:-"gated"}
CLUSTER_NODES=${CLUSTER_NODES:-3} # defaultly set to the typical 3-node cluster, and developer can set to 1 on single node cluster.
# Create benchmark client(POD) as many as the cluster nodes in the ceph storage. User can change it as needed. default is 1 client 
BENCHMARK_CLIENT_NODES=${BENCHMARK_CLIENT_NODES:-3} # VM Instance number
CPU_PLACEMENT=${CPU_PLACEMENT:-"1"}
# Fio parameters
TEST_DURATION=${TEST_DURATION:-600} # Unit: second
TEST_RAMP_TIME=${TEST_RAMP_TIME:-300} # Unit: second
TEST_IO_THREADS=${TEST_IO_THREADS:-16} # IO threads for benchmark
TEST_BLOCK_SIZE=${TEST_BLOCK_SIZE:-4096}
TEST_DATASET_SIZE=${TEST_DATASET_SIZE:-"686G"}
TEST_IO_DEPTH=${TEST_IO_DEPTH:-32}
TEST_JOBS_NUM=${TEST_JOBS_NUM:-2}  # Jobs or thread or cosbench drive nums on each node
CPUS_ALLOWED=${CPUS_ALLOWED:-1}  # cpu core invovled.
CPUS_ALLOWED_POLICY=${CPUS_ALLOWED_POLICY:-"split"}
TEST_CPUCORE_COUNT=${TEST_CPUCORE_COUNT:-4} # default use 4 cores.
TEST_OPERATION=${TEST_OPERATION:-"sequential_read"}  # read/write/randread/randwrite
TEST_IO_ENGINE=${TEST_IO_ENGINE:-"rbd"} # used for fio benchmark.
RBD_IMAGE_NUM=${RBD_IMAGE_NUM:-3} # rbd block volumn num on each client
MIXRW_RATIO=${MIXRW_RATIO:-"70"} # 70% Read ratio
## fio block device test parameters
FIO_CPU=""    # FIO job used cores number

SKIP_PREFILL=${SKIP_PREFILL:-"0"}
CHECK_CEPH_STATUS=${CHECK_CEPH_STATUS:-"1"}
RECONFIG_ROOK_CEPH=${RECONFIG_ROOK_CEPH:-"0"}

# Wait for VM being ready
WAIT_VM=${WAIT_VM:-"600"}
if [ "$SKIP_PREFILL" == "1" ]; then
    WAIT_VM=0
fi
# SPDK-Vhost VM testcase setting.
VHOST_CPU_NUM=${VHOST_CPU_NUM:-"2"}
VHOST_BDEV_NUM=${VHOST_BDEV_NUM:-"3"}
SPDK_HUGEMEM=${SPDK_HUGEMEM:-"2Gi"}  # hugememory for spdk use, default: 2Gi
SPDK_CPU_NUM=${SPDK_CPU_NUM:-"18"} # cpu number of SPDK pod, default: 18
VM_HUGEMEM=${VM_HUGEMEM:-"16Gi"} # hugemomery for VM, default: 16Gi
VM_CPU_NUM=${VM_CPU_NUM:-"32"} # cpu number of VM, default: 32
RBD_IMG_SIZE=${RBD_IMG_SIZE:-"50G"} # default: 50Gi
VHOST_DEV_BS=${VHOST_DEV_BS:-"512"}
HUGEPAGE_REQ=${HUGEPAGE_REQ:-"18432"}   # Actual request for hugepage = $SPDK_HUGEMEM + $VM_HUGEMEM, unit: Mi
VM_NAME=${VM_NAME:-"ubuntu"}

# for VM scaling setting
VM_SCALING=${VM_SCALING:-"0"} #default:0  parse VM_SCALING=1 if doing vm_scaling
MAX_VM_COUNT=${MAX_VM_COUNT:-"90"}

# traditional-VM testcase setting.
PVC_BLOCK_SIZE=${PVC_BLOCK_SIZE:-"686G"}

# Ceph common setting.
ROOK_CEPH_STORAGE_NAMESPACE="rook-ceph"
CORE_NUM_PER_OSD=${CORE_NUM_PER_OSD:-""} # CPU cores request by each OSD
MEM_NUM_PER_OSD=${MEM_NUM_PER_OSD:-""}  # memory used by each OSD(MiB)
PG_COUNT=${PG_COUNT:-""} # pg count in replicapool pool
# OSD setting for ceph stroage deployment
OSD_PER_DEVICE=1    # Each Disk can be mapped to several individual OSDs. High performance devices such as NVMe can handle running multiple OSDs
OSD_LIVENESSPROBE_DISABLE="false" # false/true Disable the OSD livenessprobe is the OSD cpu resource is saturated at some corner case.
CEPH_CLUSTER="rook-ceph"
# Ceph configmap setting
CEPH_CONFIG_ENABLED="0" # Enable ceph configuration override
OSD_MEMORY_TARGET="8589934592" # OSD memory default value: 8G

TEST_CASE="$(echo ${TESTCASE_OPT} | cut -d_ -f1)" #virtIO/vhost
TEST_OPERATION_MODE="$(echo ${TESTCASE_OPT} | cut -d_ -f2)"  # sequential/random/live-recovery/live-migration
TEST_RW_OPERATION="$(echo ${TESTCASE_OPT} | cut -d_ -f3)"   #read/write
TEST_CASE_TYPE="$(echo ${TESTCASE_OPT} | cut -d_ -f4)"   #pkm/sw/scale-1vm/scale-4vm  (scale-Xvm means running X benchmark VMs in each node)
TEST_CASE_COMP=${TEST_CASE_COMP:-"0"}

# Only for QAT module
if [ -e "$DIR"/Dockerfile.3.ceph_qat ]; then
    QAT_ENABLED="false"  #parameter in rook-config-override, default: false, true if use QAT to accelerate
    if [[ "$TEST_CASE_TYPE" == "qatcomp" || "$TEST_CASE_TYPE" == "swcomp" ]]; then
        TEST_CASE_COMP=1
        CHECK_CEPH_STATUS=0
        SKIP_PREFILL=1
        WAIT_VM=0
        TEST_JOBS_NUM=1
        if [ "$TEST_CASE_TYPE" == "qatcomp" ];then
            QAT_ENABLED="true"
        fi
    fi
fi

if [[ "$TEST_CASE_TYPE" == "scale-1vm" || "$TEST_CASE_TYPE" == "scale-4vm" ]]; then
    VM_SCALING=1
    RBD_IMAGE_NUM=1
    WAIT_VM=0
    VM_HUGEMEM="2Gi"
    VM_CPU_NUM=2
    VHOST_CPU_NUM=3
    SPDK_HUGEMEM="8Gi"
    BENCHMARK_CLIENT_NODES=$CLUSTER_NODES
    if [ "$TEST_CASE_TYPE" == "scale-4vm" ];then
       ((BENCHMARK_CLIENT_NODES = 4 * $CLUSTER_NODES ))
    fi
fi
TEST_OPERATION=${TEST_OPERATION_MODE}_${TEST_RW_OPERATION}

if [ "$TESTCASE_OPT" == "gated" ]; then
    TEST_CASE="gated";
    CLUSTER_NODES=1;
    TEST_DURATION=60; 
    TEST_DATASET_SIZE=512
    TEST_IO_THREADS=8
    BENCHMARK_CLIENT_NODES=1 # Gated case only has 1 benchmark pod.
    RBD_IMAGE_NUM=1
fi

if [[ "${TEST_CASE}" == "virtIO" || "${TEST_CASE}" == "vhost" ]];then
    TEST_IO_ENGINE="libaio" # used for fio benchmark.
    if [ "$TEST_OPERATION_MODE" == "random" ];then
        TEST_IO_DEPTH=64
        TEST_BLOCK_SIZE=4k
        if [ "$TEST_CASE_COMP" == "1" ];then
            TEST_BLOCK_SIZE=4M
        fi
    elif [ "$TEST_OPERATION_MODE" == "sequential" ];then
        TEST_IO_DEPTH=8
        TEST_BLOCK_SIZE=1M
    elif [ "$TEST_OPERATION_MODE" == "live-recovery" ];then
        TEST_OPERATION="random_read_$TEST_OPERATION_MODE"
        SKIP_PREFILL=1
        WAIT_VM=0
        TEST_DURATION=120
        TEST_RAMP_TIME=0
        # Wait for a certain time before live recovery
        WAIT_RECOVERY_TIME=${WAIT_RECOVERY_TIME:-"10"}
    elif [ "$TEST_OPERATION_MODE" == "live-migration" ];then
        TEST_OPERATION="random_read_$TEST_OPERATION_MODE"
        SKIP_PREFILL=1
        WAIT_VM=0
        TEST_DURATION=300
        TEST_RAMP_TIME=0
        BENCHMARK_CLIENT_NODES=1 # Only need one VM to verify VM live migration
        MIGRATION_TIMEOUT=${MIGRATION_TIMEOUT:-"300"}
        CPU_PLACEMENT=0
    fi
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# cluster node selector for ceph cluster deployment, use all nodes or partial of them.
# args: ALL - Deploy ceph storage on all node which labeled with "HAS-SETUP-CEPH-STORAGE=yes" with SW/HW configed as ceph needed;
#       PARTIAL - Sepcial case WSF, only constraited nodes by WSF can be used for ceph storage. WSF will provide the hostname for selected nodes.
NODE_SELECT="ALL"
# Storage device selector for ceph cluster building, use all drives or partial of them.
# args: ALL; PARTIAL
DEVICE_SELECT="ALL"

# Set the debug mode for ceph workload
# 0 - disable debug mode
# 1 - debug the benchmark operator, deploy the operator with doing nothing.
# 2 - debug the ceph cluster, will stop after ceph cluster is deployed.
# 3 - debug the ceph benchmark, will hold on the benchmark pod without any benchmark for debug.
# 4 - Hold on the benchmark Operator after finished the data collectioin on benchmark pod(s), stop before cleanup.
#     User can create the file /debug_flag to continue the process. e.g. touch /debug_flag 
# 5 - For block benchmark pod debug. Hold On after Blcok function benchmark finished. continue with CMD "touch /debug_5" in each benchmark pod
# 6 - Debug the ceph block function, stop after deploy and enable ceph block.
DEBUG_MODE="0"

# Set parameters for benchmark, pass through to benchmark operator with one parameter "BENCHMARK_OPTIONS".
BENCHMARK_OPTIONS="-DDEBUG_MODE=$DEBUG_MODE;\
-DTEST_DURATION=$TEST_DURATION;\
-DTEST_IO_THREADS=$TEST_IO_THREADS;\
-DTEST_BLOCK_SIZE=$TEST_BLOCK_SIZE;\
-DTEST_DATASET_SIZE=$TEST_DATASET_SIZE;\
-DTEST_IO_DEPTH=$TEST_IO_DEPTH;\
-DTEST_JOBS_NUM=$TEST_JOBS_NUM;\
-DTEST_CPUCORE_COUNT=$TEST_CPUCORE_COUNT;\
-DTEST_OPERATION=$TEST_OPERATION;\
-DTEST_IO_ENGINE=$TEST_IO_ENGINE;\
-DVM_SCALING=$VM_SCALING;\
-DSKIP_PREFILL=$SKIP_PREFILL;\
-DMIXRW_RATIO=$MIXRW_RATIO;\
-DCHECK_CEPH_STATUS=$CHECK_CEPH_STATUS"

# Set the configuration options for environment and workload setup. pass through with one parmeter to workload.
if [ -e "$DIR"/Dockerfile.3.ceph_qat ]; then
CONFIGURATION_OPTIONS="-DDEBUG_MODE=$DEBUG_MODE;-DNODE_SELECT=$NODE_SELECT;-DDEVICE_SELECT=$DEVICE_SELECT;-DBENCHMARK_CLIENT_NODES=$BENCHMARK_CLIENT_NODES;\
-DOSD_PER_DEVICE=$OSD_PER_DEVICE;\
-DCLUSTERNODES=$CLUSTER_NODES;\
-DWAIT_VM=$WAIT_VM;\
-DMAX_VM_COUNT=$MAX_VM_COUNT;\
-DCPU_PLACEMENT=$CPU_PLACEMENT;\
-DCEPH_CLUSTER=$CEPH_CLUSTER;\
-DCEPH_CONFIG_ENABLED=$CEPH_CONFIG_ENABLED;\
-DOSD_MEMORY_TARGET=$OSD_MEMORY_TARGET;\
-DDEBUG_MODE=$DEBUG_MODE;\
-DCORE_NUM_PER_OSD=$CORE_NUM_PER_OSD;\
-DMEM_NUM_PER_OSD=$MEM_NUM_PER_OSD;\
-DRBD_IMAGE_NUM=$RBD_IMAGE_NUM;\
-DPG_COUNT=$PG_COUNT;\
-DTEST_RAMP_TIME=$TEST_RAMP_TIME;\
-DFIO_CPU=$FIO_CPU;\
-DSPDK_HUGEMEM=$SPDK_HUGEMEM;\
-DSPDK_CPU_NUM=$SPDK_CPU_NUM;\
-DVHOST_CPU_NUM=$VHOST_CPU_NUM;\
-DWAIT_RECOVERY_TIME=$WAIT_RECOVERY_TIME;\
-DMIGRATION_TIMEOUT=$MIGRATION_TIMEOUT;\
-DVM_HUGEMEM=$VM_HUGEMEM;\
-DVM_CPU_NUM=$VM_CPU_NUM;\
-DVM_NAME=$VM_NAME;\
-DHUGEPAGE_REQ=$HUGEPAGE_REQ;\
-DPVC_BLOCK_SIZE=$PVC_BLOCK_SIZE;\
-DTEST_CASE=$TEST_CASE;\
-DTEST_OPERATION_MODE=$TEST_OPERATION_MODE;\
-DTEST_CASE_TYPE=$TEST_CASE_TYPE;\
-DTEST_CASE_COMP=$TEST_CASE_COMP;\
-DQAT_ENABLED=$QAT_ENABLED;\
-DRBD_IMG_SIZE=$RBD_IMG_SIZE"
else
CONFIGURATION_OPTIONS="-DDEBUG_MODE=$DEBUG_MODE;-DNODE_SELECT=$NODE_SELECT;-DDEVICE_SELECT=$DEVICE_SELECT;\
-DBENCHMARK_CLIENT_NODES=$BENCHMARK_CLIENT_NODES;\
-DOSD_PER_DEVICE=$OSD_PER_DEVICE;\
-DCLUSTERNODES=$CLUSTER_NODES;\
-DWAIT_VM=$WAIT_VM;\
-DMAX_VM_COUNT=$MAX_VM_COUNT;\
-DCPU_PLACEMENT=$CPU_PLACEMENT;\
-DCEPH_CLUSTER=$CEPH_CLUSTER;\
-DCEPH_CONFIG_ENABLED=$CEPH_CONFIG_ENABLED;\
-DOSD_MEMORY_TARGET=$OSD_MEMORY_TARGET;\
-DDEBUG_MODE=$DEBUG_MODE;\
-DCORE_NUM_PER_OSD=$CORE_NUM_PER_OSD;\
-DMEM_NUM_PER_OSD=$MEM_NUM_PER_OSD;\
-DRBD_IMAGE_NUM=$RBD_IMAGE_NUM;\
-DPG_COUNT=$PG_COUNT;\
-DTEST_RAMP_TIME=$TEST_RAMP_TIME;\
-DFIO_CPU=$FIO_CPU;\
-DSPDK_HUGEMEM=$SPDK_HUGEMEM;\
-DSPDK_CPU_NUM=$SPDK_CPU_NUM;\
-DVHOST_CPU_NUM=$VHOST_CPU_NUM;\
-DWAIT_RECOVERY_TIME=$WAIT_RECOVERY_TIME;\
-DMIGRATION_TIMEOUT=$MIGRATION_TIMEOUT;\
-DVM_HUGEMEM=$VM_HUGEMEM;\
-DVM_CPU_NUM=$VM_CPU_NUM;\
-DVM_NAME=$VM_NAME;\
-DHUGEPAGE_REQ=$HUGEPAGE_REQ;\
-DPVC_BLOCK_SIZE=$PVC_BLOCK_SIZE;\
-DTEST_CASE=$TEST_CASE;\
-DTEST_OPERATION_MODE=$TEST_OPERATION_MODE;\
-DTEST_CASE_TYPE=$TEST_CASE_TYPE;\
-DTEST_CASE_COMP=$TEST_CASE_COMP;\
-DRBD_IMG_SIZE=$RBD_IMG_SIZE"
fi

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
BENCH_OPERATOR_NAME="edge-ceph-benchmark-operator"
JOB_FILTER="app=${BENCH_OPERATOR_NAME}"

RECONFIG_OPTIONS=" -DTEST_CASE=$TEST_CASE \
-DDEBUG_MODE=$DEBUG_MODE \
-DBENCH_OPERATOR_NAME=$BENCH_OPERATOR_NAME \
-DCLUSTERNODES=$CLUSTER_NODES \
-DTEST_DURATION=$TEST_DURATION \
-DROOK_CEPH_STORAGE_NAMESPACE=$ROOK_CEPH_STORAGE_NAMESPACE \
-DBENCHMARK_OPTIONS=$BENCHMARK_OPTIONS \
-DCONFIGURATION_OPTIONS=$CONFIGURATION_OPTIONS "

# Workload Setting
WORKLOAD_PARAMS=(TEST_CASE \
BENCH_OPERATOR_NAME \
CLUSTER_NODES \
TEST_DURATION \
ROOK_CEPH_STORAGE_NAMESPACE \
BENCHMARK_OPTIONS \
CONFIGURATION_OPTIONS \
)

# Script Setting
SCRIPT_ARGS="$TEST_OPERATION"

# Emon Test Setting
EVENT_TRACE_PARAMS="roi,Start benchmark,Finish benchmark"

TIMEOUT=${TIMEOUT:-3000}
. "$DIR/../../script/validate.sh"

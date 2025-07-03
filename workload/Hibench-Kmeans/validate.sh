#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function concat_params() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="$i"
        else
            RET="${RET} $i"
        fi
    done
    echo "$RET"
} 

function workload_settings() {
    RET=""
    for i in "$@"; do
        LOWER=$(echo "$i" | tr '[:upper:]' '[:lower:]')
        if [[ "$RET" == "" ]]; then
            RET="${LOWER}:$(eval echo \$$i)"
        else
            RET="${RET};${LOWER}:$(eval echo \$$i)"
        fi
    done
    echo "$RET"
}

function k8s_settings() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="-D$i=\$$i"
        else
            RET="${RET} -D$i=\$$i"
        fi
    done
    echo "$RET"
}

### General settings
ENABLE_MOUNT_DIR=${ENABLE_MOUNT_DIR:-false}
MOUNT_DIR=${MOUNT_DIR:-"/mnt/disk"}
DISK_COUNT=${DISK_COUNT:-1}
WORKER_MEMORY=${WORKER_MEMORY:-auto}
WORKER_CPU_CORES=${WORKER_CPU_CORES:-auto}
if [ "${TESTCASE}" != "${TESTCASE%_gated}" ]; then
    echo "gated testcase"
    WORKERNODE_NUM=1
    NODE_NUM=1 # namenode+datanode=1
else
    WORKERNODE_NUM=3
    NODE_NUM=$((WORKERNODE_NUM+1)) # namenode=1 datanode=4
fi
GENERAL_KEYS="ENABLE_MOUNT_DIR MOUNT_DIR DISK_COUNT NODE_NUM WORKERNODE_NUM WORKER_MEMORY WORKER_CPU_CORES"



###HiBench settings
#/HiBench/conf/hibench.conf
HIBENCH_SCALE_PROFILE=${HIBENCH_SCALE_PROFILE:-tiny}
HIBENCH_DEFAULT_MAP_PARALLELISM=${HIBENCH_DEFAULT_MAP_PARALLELISM:-auto}
HIBENCH_DEFAULT_SHUFFLE_PARALLELISM=${HIBENCH_DEFAULT_SHUFFLE_PARALLELISM:-auto}
HIBENCH_KEYS="WORKLOAD HIBENCH_SCALE_PROFILE \
HIBENCH_DEFAULT_MAP_PARALLELISM HIBENCH_DEFAULT_SHUFFLE_PARALLELISM"



#Kmeans settings
#/HiBench/conf/workloads/ml/kmeans.conf
#overwrite kmeans.conf if a number is given; 
#eg. if user choose "huge" profile, hibench.kmeans.huge.num_of_samples will be overwritten.
#1 hibench.kmeans.num_of_samples
HIBENCH_KMEANS_NUM_OF_SAMPLES=${HIBENCH_KMEANS_NUM_OF_SAMPLES:-default}
#eg. if user choose "big" profile, hibench.kmeans.big.samples_per_inputfile will be overwritten.
#2 hibench.kmeans.samples_per_inputfile
HIBENCH_KMEANS_SAMPLES_PER_INPUTFILE=${HIBENCH_KMEANS_SAMPLES_PER_INPUTFILE:-default}
#3 hibench.kmeans.num_of_clusters
HIBENCH_KMEANS_NUM_OF_CLUSTERS=${HIBENCH_KMEANS_NUM_OF_CLUSTERS:-default}
#4 hibench.kmeans.dimensions
HIBENCH_KMEANS_DIMENSIONS=${HIBENCH_KMEANS_DIMENSIONS:-default}
#5 hibench.kmeans.max_iteration
HIBENCH_KMEANS_MAX_ITERATION=${HIBENCH_KMEANS_MAX_ITERATION:-40}
#6 hibench.kmeans.k
HIBENCH_KMEANS_K=${HIBENCH_KMEANS_K:-300}
#7 hibench.kmeans.convergedist
HIBENCH_KMEANS_CONVERGEDIST=${HIBENCH_KMEANS_CONVERGEDIST:-0.5}

KMEANS_KEYS="HIBENCH_KMEANS_NUM_OF_SAMPLES HIBENCH_KMEANS_SAMPLES_PER_INPUTFILE HIBENCH_KMEANS_NUM_OF_CLUSTERS HIBENCH_KMEANS_DIMENSIONS HIBENCH_KMEANS_MAX_ITERATION HIBENCH_KMEANS_K HIBENCH_KMEANS_CONVERGEDIST"



###Spark settings
#/HiBench/conf/spark.conf
#1 hibench.yarn.executor.num
HIBENCH_YARN_EXECUTOR_NUM=${HIBENCH_YARN_EXECUTOR_NUM:-auto}
#2 hibench.yarn.executor.cores
HIBENCH_YARN_EXECUTOR_CORES=${HIBENCH_YARN_EXECUTOR_CORES:-auto}
#3 spark.executor.memory (GB) eg.8g
SPARK_EXECUTOR_MEMORY=${SPARK_EXECUTOR_MEMORY:-auto}
#4 spark.executor.memoryOverhead (GB) eg.3g
SPARK_EXECUTOR_MEMORYOVERHEAD=${SPARK_EXECUTOR_MEMORYOVERHEAD:-auto}
#5 spark.driver.memory (GB) eg.8g
SPARK_DRIVER_MEMORY=${SPARK_DRIVER_MEMORY:-auto}
#6 spark.default.parallelism     
SPARK_DEFAULT_PARALLELISM=${SPARK_DEFAULT_PARALLELISM:-auto}
#7 spark.sql.shuffle.partitions
SPARK_SQL_SHUFFLE_PARTITIONS=${SPARK_SQL_SHUFFLE_PARTITIONS:-auto}
#8 hibench.spark.master
HIBENCH_SPARK_MASTER=${HIBENCH_SPARK_MASTER:-yarn}
SPARK_KEYS="HIBENCH_YARN_EXECUTOR_NUM HIBENCH_YARN_EXECUTOR_CORES \
SPARK_EXECUTOR_MEMORY SPARK_DRIVER_MEMORY SPARK_EXECUTOR_MEMORYOVERHEAD \
SPARK_DEFAULT_PARALLELISM SPARK_SQL_SHUFFLE_PARTITIONS HIBENCH_SPARK_MASTER"



###YARN settings
#/usr/local/hadoop/etc/hadoop/yarn-site.xml
#1 yarn.scheduler.minimum-allocation-mb
YARN_SCHEDULER_MINIMUM_ALLOCATION_MB=${YARN_SCHEDULER_MINIMUM_ALLOCATION_MB:-1024}
#2 yarn.scheduler.maximum-allocation-mb
YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB=${YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB:-auto}
#3 yarn.scheduler.minimum-allocation-vcores
YARN_SCHEDULER_MINIMUM_ALLOCATION_VCORES=${YARN_SCHEDULER_MINIMUM_ALLOCATION_VCORES:-1}
#4 yarn.scheduler.maximum-allocation-vcores
YARN_SCHEDULER_MAXIMUM_ALLOCATION_VCORES=${YARN_SCHEDULER_MAXIMUM_ALLOCATION_VCORES:-auto}
#5 yarn.nodemanager.vmem-pmem-ratio
YARN_NODEMANAGER_VMEM_PMEM_RATIO=${YARN_NODEMANAGER_VMEM_PMEM_RATIO:-2.1}
#6 yarn.nodemanager.resource.percentage-physical-cpu-limit
YARN_NODEMANAGER_RESOURCE_PERCENTAGE_PHYSICAL_CPU_LIMIT=${YARN_NODEMANAGER_RESOURCE_PERCENTAGE_PHYSICAL_CPU_LIMIT:-100}
#7 yarn.nodemanager.resource.memory-mb
YARN_NODEMANAGER_RESOURCE_MEMORY_MB=${YARN_NODEMANAGER_RESOURCE_MEMORY_MB:-auto}
#8 yarn.nodemanager.resource.cpu-vcores
YARN_NODEMANAGER_RESOURCE_CPU_VCORES=${YARN_NODEMANAGER_RESOURCE_CPU_VCORES:-auto}
#9 yarn.resourcemanager.scheduler.client.thread-count
YARN_RESOURCEMANAGER_SCHEDULER_CLIENT_THREAD_COUNT=${YARN_RESOURCEMANAGER_SCHEDULER_CLIENT_THREAD_COUNT:-50}
YARN_KEYS="YARN_SCHEDULER_MINIMUM_ALLOCATION_MB YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB \
YARN_SCHEDULER_MINIMUM_ALLOCATION_VCORES YARN_SCHEDULER_MAXIMUM_ALLOCATION_VCORES \
YARN_NODEMANAGER_VMEM_PMEM_RATIO YARN_NODEMANAGER_RESOURCE_PERCENTAGE_PHYSICAL_CPU_LIMIT \
YARN_NODEMANAGER_RESOURCE_MEMORY_MB YARN_NODEMANAGER_RESOURCE_CPU_VCORES \
YARN_RESOURCEMANAGER_SCHEDULER_CLIENT_THREAD_COUNT"



###MapReduce settings
#/usr/local/hadoop/etc/hadoop/mapred-site.xml
#1 mapreduce.map.cpu.vcores
MAPREDUCE_MAP_CPU_VCORES=${MAPREDUCE_MAP_CPU_VCORES:-1}
#2 mapreduce.reduce.cpu.vcores
MAPREDUCE_REDUCE_CPU_VCORES=${MAPREDUCE_REDUCE_CPU_VCORES:-1}
#3 mapreduce.task.io.sort.factor
MAPREDUCE_TASK_IO_SORT_FACTOR=${MAPREDUCE_TASK_IO_SORT_FACTOR:-64}
#4 mapreduce.task.io.sort.mb
MAPREDUCE_TASK_IO_SORT_MB=${MAPREDUCE_TASK_IO_SORT_MB:-512}
#5 mapreduce.map.sort.spill.percent
MAPREDUCE_MAP_SORT_SPILL_PERCENT=${MAPREDUCE_MAP_SORT_SPILL_PERCENT:-0.8}
#6 mapreduce.job.reduce.slowstart.completedmaps	
MAPREDUCE_JOB_REDUCE_SLOWSTART_COMPLETEDMAPS=${MAPREDUCE_JOB_REDUCE_SLOWSTART_COMPLETEDMAPS:-1}
#7 mapreduce.output.fileoutputformat.compress.codec
MAPREDUCE_OUTPUT_FILEOUTPUTFORMAT_COMPRESS_CODEC=${MAPREDUCE_OUTPUT_FILEOUTPUTFORMAT_COMPRESS_CODEC:-org.apache.hadoop.io.compress.SnappyCodec}
MAP_KEYS="MAPREDUCE_MAP_CPU_VCORES MAPREDUCE_REDUCE_CPU_VCORES MAPREDUCE_TASK_IO_SORT_FACTOR MAPREDUCE_TASK_IO_SORT_MB \
MAPREDUCE_MAP_SORT_SPILL_PERCENT MAPREDUCE_JOB_REDUCE_SLOWSTART_COMPLETEDMAPS MAPREDUCE_OUTPUT_FILEOUTPUTFORMAT_COMPRESS_CODEC"



###DFS settings
#/usr/local/hadoop/etc/hadoop/hdfs-site.xml
# dfs.namenode.handler.count
DFS_NAMENODE_HANDLER_COUNT=${DFS_NAMENODE_HANDLER_COUNT:-30}
# dfs.datanode.handler.count
DFS_DATANODE_HANDLER_COUNT=${DFS_DATANODE_HANDLER_COUNT:-30}
# dfs.blocksize
DFS_BLOCKSIZE=${DFS_BLOCKSIZE:-128m}
DFS_KEYS="DFS_NAMENODE_HANDLER_COUNT DFS_DATANODE_HANDLER_COUNT DFS_BLOCKSIZE"



DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

ALL_KEYS="$(concat_params $GENERAL_KEYS $HIBENCH_KEYS $KMEANS_KEYS $YARN_KEYS $MAP_KEYS $SPARK_KEYS $DFS_KEYS)"
WORKLOAD_PARAMS=($ALL_KEYS)

SCRIPT_ARGS="${WORKERNODE_NUM}"
EVENT_TRACE_PARAMS="roi,begin region of interest,end region of interest"

# Docker settings
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes settings
RECONFIG_OPTIONS=$(eval echo "$(k8s_settings $ALL_KEYS)")
JOB_FILTER="job-name=hibench-benchmark"

echo $DIR
. "$DIR/../../script/validate.sh"

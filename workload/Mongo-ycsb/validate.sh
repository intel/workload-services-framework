#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Logs Setting
DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"

# workload params
CLIENT_SERVER_PAIR=${CLIENT_SERVER_PAIR:=3}                         ## mongod instance number
RUN_SINGLE_NODE=${RUN_SINGLE_NODE:=false}                           ## if you want to run the workload on single node, set it true
CONFIG_CENTER_PORT=${CONFIG_CENTER_PORT:=16379}                     ## config-center(redis) service port
TLS_FLAG=${TLS_FLAG:=0}                                             ## Security TLS flag
EVENT_TRACE_PARAMS="roi,RUN PHASE,benchmark-finish"                 ## EVENT_TRACE_PARAMS for collecting trace data
CLIENT_COUNT=${CLIENT_COUNT:=1}                                     ## number of client nodes to run ycsb instances;
                                                                    #### If you want to make full use of the CPU on the server side, 
                                                                    #### this value needs to be adjusted according to the number of the mongodb instance
NUMACTL_OPTION=${NUMACTL_OPTION:='0'}                               ## numactl param
                                                                    ####0 - mongodb default bind, numactl --interleave=all
                                                                    ####1 - numactl -N <cpunode> -M <memorynode> , bind all mongodb instances to all numanode evenly
                                                                    ####2 - numactl -N <cpunode> -M <memorynode> , bind all mongodb instances to a numanode
                                                                    ####3 - used in combination with `CORE_NUMS_EACH_INSTANCE` to bind each mongodb instance with specific number of cores
                                                                    ####4 - used in combination with `CORE_NUMS_EACH_INSTANCE` to bind each mongodb instance with specific number of cores and their paired logical cores
CORE_NUMS_EACH_INSTANCE=${CORE_NUMS_EACH_INSTANCE:=""}              ## the number of cores you want to bind for each mongodb instance
SELECT_NUMA_NODE=${SELECT_NUMA_NODE:='0'}                           ## if NUMACTL_OPTION was set to 2, this is the selected numa node; for other NUMACTL_OPTION, this is meaningless
CORES=${CORES:=''}                                                  ## if NUMACTL_OPTION was set to 2, this is the selected cores on selected numa node, like 0, or 0,1 , or 0-7
YCSB_CORES=${YCSB_CORES:=''}                                        ## this is the selected cores bounded with ycsb instances. you can set it like 32-63
CUSTOMER_NUMAOPT_CLIENT=${CUSTOMER_NUMAOPT_CLIENT:=""}              ## customer numactl parameters for YCSB
CUSTOMER_NUMAOPT_SERVER=${CUSTOMER_NUMAOPT_SERVER:=""}              ## customer numactl parameters for MongoDB
                                                                    #### customer parameters take effect in single-node scenarios, these two are the most significiant parameters 
                                                                    #### and will overwrite all numa-related parameters. You can set it as using `numactl` dirctly
                                                                    #### e.g. CUSTOMER_NUMAOPT_CLIENT="-N 1 -M 1"; CUSTOMER_NUMAOPT_SERVER="-N 0 -M 0"
DB_HUGEPAGE_STATUS=${DB_HUGEPAGE_STATUS:=false}                     ## enable/disable transparent hugepages
KERNEL_SETTING_OPTIMIZED=${KERNEL_SETTING_OPTIMIZED:=true}          ## optimize the workload by kernel setting, include: zone_reclaim_mode/numa_balancing

# ycsb params
WORKLOAD_FILE=${WORKLOAD_FILE:="90Read10Update"}                    ## The workload class to use
THREADS=${THREADS:=10}                                              ## Indicates the number of YCSB client threads
RECORD_COUNT=${RECORD_COUNT:=""}                                    ## Indicates the number of YCSB instance records used in load and run phases
OPERATION_COUNT=${OPERATION_COUNT:=""}                              ## Indicates the number of YCSB instance operands used in load and run phases
INSERT_START=${INSERT_START:=""}                                    ## offset of the first inserted value                                 
INSERT_COUNT=${INSERT_COUNT:=""}                                    ## refers to the number of records that were inserted into the database
INSERT_ORDER=${INSERT_ORDER:=""}                                    ## specifies the order in which new records are inserted into the database
READ_PROPORTION=${READ_PROPORTION:=""}                              ## Indicates the ratio of read operations to all operations
UPDATE_PROPORTION=${UPDATE_PROPORTION:=""}                          ## Indicates the ratio of update operations to all operations
INSERT_PROPORTION=${INSERT_PROPORTION:=""}                          ## Indicates the ratio of insert operations to all operations
SCAN_PROPORTION=${SCAN_PROPORTION:=""}                              ## Indicates the ratio of scan operations to all operations
TARGET=${TARGET:=""}                                                ## Control data transfers, limiting the number of operations performed per second
FIELD_COUNT=${FIELD_COUNT:=""}                                      ## The number of fields in the record
FIELD_LENGTH=${FIELD_LENGTH:=""}                                    ## Field size
MIN_FIELD_LENGTH=${MIN_FIELD_LENGTH:=""}                            ## Minimun field size
READ_ALL_FIELDS=${READ_ALL_FIELDS:=""}                              ## Should read all fields (true), only one (false)
WRITE_ALL_FIELDS=${WRITE_ALL_FIELDS:=""}                            ## Should write all fields (true), only one (false)
READ_MODIFY_WRITE_PROPORTION=${READ_MODIFY_WRITE_PROPORTION:=""}    ## Refers to the proportion of operations that read a record, modify it, and write it back
REQUEST_DISTRIBUTION=${REQUEST_DISTRIBUTION:=""}                    ## What distribution should be used to select records to operate on: uniform, zipfian, hotspot, sequential, exponential and latest
MIN_SCANLENGTH=${MIN_SCANLENGTH:=""}                                ## Minimum number of records to scan
MAX_SCANLENGTH=${MAX_SCANLENGTH:=""}                                ## Maximum number of records to scan
SCAN_LENGTH_DISTRIBUTION=${SCAN_LENGTH_DISTRIBUTION:=""}            ## What distribution should be used for scans to choose the number of records to scan, between 1 and maxscanlength for each scan
ZERO_PADDING=${ZERO_PADDING:=""}                                    ## specifies whether leading zeros should be added to record keys to ensure they have a consistent length
FIELD_NAME_PREFIX=${FIELD_NAME_PREFIX:=""}                          ## specifies a prefix to be added to the field names of records
MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:=""}                        ## specifies the maximum duration for a workload execution
JVM_ARGS=${JVM_ARGS:='-XX:+UseNUMA'}                                ## specifies the command-line arguments to be passed to the JVM
YCSB_MEASUREMENT_TYPE=${YCSB_MEASUREMENT_TYPE:=""}                  ## Indicates how to present latency measurement timeseries

# mongodb params
CACHE_SIZE_GB=${CACHE_SIZE_GB:=''}                                               ## specifies the maximum amount of memory that can be used by the WT's cache in gigabytes
JOURNAL_ENABLED=${JOURNAL_ENABLED:=false}                                        ## determines whether write operations are recorded in the database's journal.
JOURNAL_COMPRESSOR=${JOURNAL_COMPRESSOR:=snappy}                                 ## compresses the journal files written by MongoDB's WiredTiger storage engine
COLLECTIONCONFIG_BLOCKCOMPRESSOR=${COLLECTIONCONFIG_BLOCKCOMPRESSOR:=snappy}     ## specifies the compression algorithm to use for block-level compression of data in a collection.
PROCESS_MANAGEMENT_FORK=${PROCESS_MANAGEMENT_FORK:=true}                         ## Used to run the MongoDB server process in daemon mode in the background
DB_HOSTPATH=${DB_HOSTPATH:=''}                                                   ## the mounted path on host for mongodb instancens
DISK_SPEC=${DISK_SPEC:=false}                                                    ## specifies disk spec for mongodb instances

# kubernetes params
KUBERNETES_RESOURCE_REQUESTS=${KUBERNETES_RESOURCE_REQUESTS:=true}               ## resource requests (cpu and memory) of kubernetes
KUBERNETES_RESOURCE_REQUESTS_CPU=${KUBERNETES_RESOURCE_REQUESTS_CPU:=1}
KUBERNETES_RESOURCE_REQUESTS_MEMORY=${KUBERNETES_RESOURCE_REQUESTS_MEMORY:=""}
KUBERNETES_RESOURCE_LIMITS=${KUBERNETES_RESOURCE_LIMITS:=false}                  ## resource limits (cpu and memory) of kubernetes
KUBERNETES_RESOURCE_LIMITS_CPU=${KUBERNETES_RESOURCE_LIMITS_CPU:=""}
KUBERNETES_RESOURCE_LIMITS_MEMORY=${KUBERNETES_RESOURCE_LIMITS_MEMORY:=""}

# testcase
if [[ "$TESTCASE" =~ "_gated"$ ]]; then
    THREADS=1
    OPERATION_COUNT=10000
    RECORD_COUNT=1000
    INSERT_START=0
    INSERT_COUNT=0
    CLIENT_SERVER_PAIR=1
    READ_PROPORTION=0.90
    UPDATE_PROPORTION=0.10
    INSERT_PROPORTION=0
    SCAN_PROPORTION=0
    CLIENT_COUNT=1
elif [[ "$TESTCASE" =~ "_90read10update"$ ]]; then
    READ_PROPORTION=0.90
    UPDATE_PROPORTION=0.10
    INSERT_PROPORTION=0
    SCAN_PROPORTION=0
elif [[ "$TESTCASE" =~ "_30write70read"$ ]]; then
    READ_PROPORTION=0.70
    UPDATE_PROPORTION=0
    INSERT_PROPORTION=0.30
    SCAN_PROPORTION=0
elif [[ "$TESTCASE" =~ "_write"$ ]]; then
    READ_PROPORTION=0
    UPDATE_PROPORTION=0
    INSERT_PROPORTION=1.0
    SCAN_PROPORTION=0
elif [[ "$TESTCASE" =~ "_read"$ ]]; then
    READ_PROPORTION=1.0
    UPDATE_PROPORTION=0
    INSERT_PROPORTION=0
    SCAN_PROPORTION=0
elif [[ "$TESTCASE" =~ "_iaa"$ ]]; then
    HERO_FEATURE_IAA=true
fi

. "$DIR/../../script/overwrite.sh"

if [[ "$RUN_SINGLE_NODE" = true ]]; then
    CLIENT_COUNT=0
elif [ $CLIENT_COUNT -eq 0 ]; then
    RUN_SINGLE_NODE=true
fi

# maxSkew describes the degree to which Pods may be unevenly distributed
if [ $CLIENT_COUNT -ne 0 ]; then
    let MAX_SKEW=(CLIENT_SERVER_PAIR + CLIENT_COUNT - 1)/CLIENT_COUNT
else
    let MAX_SKEW=${CLIENT_SERVER_PAIR}
fi

NUM_DBPATH=$(echo $DB_HOSTPATH | awk -F'%20' '{print NF}')
RECONFIG_OPTIONS="-DNUM_DBPATH=${NUM_DBPATH}"
END=$(($NUM_DBPATH+27017))
if [ $NUM_DBPATH -ne 0 ]; then
    for ((i=27017; i<$END; i++)); do
        eval DBPATH${i}=$(echo $DB_HOSTPATH | awk -F'%20' -v n=$(($i-27016)) '{print $n}');
	RECONFIG_OPTIONS="$RECONFIG_OPTIONS -DDBPATH${i}=$(eval echo '$'DBPATH${i})";
    done
fi

# Workload Setting
WORKLOAD_PARAMS=( 
CLIENT_SERVER_PAIR 
THREADS 
OPERATION_COUNT 
RECORD_COUNT 
INSERT_START 
INSERT_COUNT 
FIELD_COUNT 
FIELD_LENGTH 
MIN_FIELD_LENGTH 
READ_ALL_FIELDS 
WRITE_ALL_FIELDS 
READ_PROPORTION 
UPDATE_PROPORTION 
INSERT_PROPORTION 
SCAN_PROPORTION 
READ_MODIFY_WRITE_PROPORTION 
REQUEST_DISTRIBUTION 
MIN_SCANLENGTH 
MAX_SCANLENGTH 
SCAN_LENGTH_DISTRIBUTION 
ZERO_PADDING 
INSERT_ORDER 
FIELD_NAME_PREFIX 
NUMACTL_OPTION 
CORE_NUMS_EACH_INSTANCE
CORES 
SELECT_NUMA_NODE 
MAX_EXECUTION_TIME 
JVM_ARGS 
CONFIG_CENTER_PORT  
CACHE_SIZE_GB 
JOURNAL_ENABLED 
JOURNAL_COMPRESSOR
COLLECTIONCONFIG_BLOCKCOMPRESSOR 
PROCESS_MANAGEMENT_FORK 
TARGET 
DB_HOSTPATH 
DISK_SPEC 
TLS_FLAG 
DB_HUGEPAGE_STATUS 
KERNEL_SETTING_OPTIMIZED
YCSB_MEASUREMENT_TYPE  
RUN_SINGLE_NODE 
CUSTOMER_NUMAOPT_CLIENT 
CUSTOMER_NUMAOPT_SERVER 
YCSB_CORES 
CLIENT_COUNT
KUBERNETES_RESOURCE_REQUESTS
KUBERNETES_RESOURCE_REQUESTS_CPU
KUBERNETES_RESOURCE_REQUESTS_MEMORY
KUBERNETES_RESOURCE_LIMITS
KUBERNETES_RESOURCE_LIMITS_CPU
KUBERNETES_RESOURCE_LIMITS_MEMORY)

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="${RECONFIG_OPTIONS} \
-DCLIENT_SERVER_PAIR=${CLIENT_SERVER_PAIR} \
-DWORKLOAD_FILE=${WORKLOAD_FILE} \
-DTHREADS=${THREADS} \
-DOPERATION_COUNT=${OPERATION_COUNT} \
-DRECORD_COUNT=${RECORD_COUNT} \
-DINSERT_START=${INSERT_START} \
-DINSERT_COUNT=${INSERT_COUNT} \
-DFIELD_COUNT=${FIELD_COUNT} \
-DFIELD_LENGTH=${FIELD_LENGTH} \
-DMIN_FIELD_LENGTH=${MIN_FIELD_LENGTH} \
-DREAD_ALL_FIELDS=${READ_ALL_FIELDS} \
-DWRITE_ALL_FIELDS=${WRITE_ALL_FIELDS} \
-DREAD_PROPORTION=${READ_PROPORTION} \
-DUPDATE_PROPORTION=${UPDATE_PROPORTION} \
-DINSERT_PROPORTION=${INSERT_PROPORTION} \
-DSCAN_PROPORTION=${SCAN_PROPORTION} \
-DREAD_MODIFY_WRITE_PROPORTION=${READ_MODIFY_WRITE_PROPORTION} \
-DREQUEST_DISTRIBUTION=${REQUEST_DISTRIBUTION} \
-DMIN_SCANLENGTH=${MIN_SCANLENGTH} \
-DMAX_SCANLENGTH=${MAX_SCANLENGTH} \
-DSCAN_LENGTH_DISTRIBUTION=${SCAN_LENGTH_DISTRIBUTION} \
-DZERO_PADDING=${ZERO_PADDING} \
-DINSERT_ORDER=${INSERT_ORDER} \
-DFIELD_NAME_PREFIX=${FIELD_NAME_PREFIX} \
-DSELECT_NUMA_NODE=${SELECT_NUMA_NODE} \
-DCORES=${CORES} \
-DNUMACTL_OPTION=${NUMACTL_OPTION} \
-DCORE_NUMS_EACH_INSTANCE=${CORE_NUMS_EACH_INSTANCE} \
-DMAX_SKEW=${MAX_SKEW} \
-DMAX_EXECUTION_TIME=${MAX_EXECUTION_TIME} \
-DJVM_ARGS=${JVM_ARGS} \
-DCONFIG_CENTER_PORT=${CONFIG_CENTER_PORT} \
-DCACHE_SIZE_GB=${CACHE_SIZE_GB} \
-DJOURNAL_ENABLED=${JOURNAL_ENABLED} \
-DJOURNAL_COMPRESSOR=${JOURNAL_COMPRESSOR} \
-DCOLLECTIONCONFIG_BLOCKCOMPRESSOR=${COLLECTIONCONFIG_BLOCKCOMPRESSOR} \
-DPROCESS_MANAGEMENT_FORK=${PROCESS_MANAGEMENT_FORK} \
-DTARGET=${TARGET} \
-DDB_HOSTPATH=${DB_HOSTPATH} \
-DDISK_SPEC=${DISK_SPEC} \
-DTLS_FLAG=${TLS_FLAG} \
-DDB_HUGEPAGE_STATUS=${DB_HUGEPAGE_STATUS} \
-DKERNEL_SETTING_OPTIMIZED=${KERNEL_SETTING_OPTIMIZED} \
-DYCSB_MEASUREMENT_TYPE=${YCSB_MEASUREMENT_TYPE} \
-DRUN_SINGLE_NODE=${RUN_SINGLE_NODE} \
-DCUSTOMER_NUMAOPT_CLIENT=${CUSTOMER_NUMAOPT_CLIENT} \
-DCUSTOMER_NUMAOPT_SERVER=${CUSTOMER_NUMAOPT_SERVER} \
-DYCSB_CORES=${YCSB_CORES} \
-DCLIENT_COUNT=${CLIENT_COUNT} \
-DHERO_FEATURE_IAA=${HERO_FEATURE_IAA} \
-DNUMBER_OF_IAA_DEVICES=${NUMBER_OF_IAA_DEVICES} \
-DKUBERNETES_RESOURCE_REQUESTS=${KUBERNETES_RESOURCE_REQUESTS} \
-DKUBERNETES_RESOURCE_REQUESTS_CPU=${KUBERNETES_RESOURCE_REQUESTS_CPU} \
-DKUBERNETES_RESOURCE_REQUESTS_MEMORY=${KUBERNETES_RESOURCE_REQUESTS_MEMORY} \
-DKUBERNETES_RESOURCE_LIMITS=${KUBERNETES_RESOURCE_LIMITS} \
-DKUBERNETES_RESOURCE_LIMITS_CPU=${KUBERNETES_RESOURCE_LIMITS_CPU} \
-DKUBERNETES_RESOURCE_LIMITS_MEMORY=${KUBERNETES_RESOURCE_LIMITS_MEMORY}"

JOB_FILTER="job-name=benchmark,name=mongodb-server"

. "$DIR/../../script/validate.sh"

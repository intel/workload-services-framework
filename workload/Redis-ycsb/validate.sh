#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# workload parameters
INSTANCE_NUM=${INSTANCE_NUM:=24}
REDIS_NUMACTL_STRATEGY=${REDIS_NUMACTL_STRATEGY:=1}
CLIENT_COUNT=${CLIENT_COUNT:=1}
NUMA_NODE_FOR_REDIS_SERVER=${NUMA_NODE_FOR_REDIS_SERVER:=0}
HOST_NETWORK_ENABLE=${HOST_NETWORK_ENABLE:=true}
PERFORMANCE_PHASE_MODE=${PERFORMANCE_PHASE_MODE:='run'}
### EVENT_TRACE_PARAMS for collecting emon data
EVENT_TRACE_PARAMS="roi,start region of interest,end region of interest"

# redis server configuration
REDIS_SERVER_IO_THREADS=${REDIS_SERVER_IO_THREADS:=0}
REDIS_SERVER_IO_THREADS_DO_READS=${REDIS_SERVER_IO_THREADS_DO_READS:="false"}
REDIS_PERSISTENCE_POLICY=${REDIS_PERSISTENCE_POLICY:="false"}                         ## with value of "false/AOF/RDB/default" ##
REDIS_APPENDFSYNC_MODE=${REDIS_APPENDFSYNC_MODE:="everysec"}                          ## with value of "always/everysec/no" ##
REDIS_RDB_SECONDS=${REDIS_RDB_SECONDS:=""}                                            ## 60
REDIS_RDB_CHANGES=${REDIS_RDB_CHANGES:=""}                                          ## 1000
REDIS_SERVER_IO_THREADS_CPU_AFFINITY=${REDIS_SERVER_IO_THREADS_CPU_AFFINITY:="false"} ## false or a string, like 0-7:2 ##
REDIS_EVICTION_POLICY=${REDIS_EVICTION_POLICY:="false"}                               ## false/noeviction/allkeys-lru/volatile-lru/allkeys-random/volatile-random/volatile-ttl

UBUNTU_OS=${UBUNTU_OS:="2404"}

# ycsb client parameters
WORKLOAD_FILE=${WORKLOAD_FILE:="workloadb"}                         ## The workload class to use
THREADS=${THREADS:=10}                                              ## Indicates the number of YCSB client threads
RECORD_COUNT=${RECORD_COUNT:="2000000"}                             ## Indicates the number of YCSB instance records used in load and run phases
OPERATION_COUNT=${OPERATION_COUNT:="2000000"}                       ## Indicates the number of YCSB instance operands used in load and run phases
INSERT_START=${INSERT_START:=""}                                    ## Offset of the first inserted value                                 
INSERT_COUNT=${INSERT_COUNT:=""}                                    ## Refers to the number of records that were inserted into the database
INSERT_ORDER=${INSERT_ORDER:=""}                                    ## Specifies the order in which new records are inserted into the database
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
ZERO_PADDING=${ZERO_PADDING:=""}                                    ## Specifies whether leading zeros should be added to record keys to ensure they have a consistent length
FIELD_NAME_PREFIX=${FIELD_NAME_PREFIX:=""}                          ## Specifies a prefix to be added to the field names of records
MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:=""}                        ## Specifies the maximum duration for a workload execution
JVM_ARGS=${JVM_ARGS:='-XX:+UseNUMA'}                                ## Specifies the command-line arguments to be passed to the JVM
YCSB_MEASUREMENT_TYPE=${YCSB_MEASUREMENT_TYPE:=""}                  ## Indicates how to present latency measurement timeseries

# Testcases overwrite for pkm
if [[ "${TESTCASE}" =~ "pkm"$ ]]; then
  INSTANCE_NUM=24
  RECORDCOUNT=2000000
  THREADS=48
  HOST_NETWORK_ENABLE=true
elif [[ "${TESTCASE}" =~ "gated"$ ]]; then
  INSTANCE_NUM=1
  RECORDCOUNT=10000
  THREADS=1
fi

if [[ "${TESTCASE}" =~ ^test.*_ubuntu2404.* ]]; then
        UBUNTU_OS="2404"
elif [[ "${TESTCASE}" =~ ^test.*_ubuntu2204.* ]]; then
        UBUNTU_OS="2204"
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(
TESTCASE
INSTANCE_NUM
REDIS_NUMACTL_STRATEGY
CLIENT_COUNT
NUMA_NODE_FOR_REDIS_SERVER
HOST_NETWORK_ENABLE
PERFORMANCE_PHASE_MODE
REDIS_SERVER_IO_THREADS
REDIS_SERVER_IO_THREADS_DO_READS
REDIS_PERSISTENCE_POLICY
REDIS_APPENDFSYNC_MODE
REDIS_RDB_SECONDS
REDIS_RDB_CHANGES
REDIS_SERVER_IO_THREADS_CPU_AFFINITY
REDIS_EVICTION_POLICY
WORKLOAD_FILE
THREADS
RECORD_COUNT
OPERATION_COUNT
INSERT_START
INSERT_COUNT
INSERT_ORDER
READ_PROPORTION
UPDATE_PROPORTION
INSERT_PROPORTION
SCAN_PROPORTION
TARGET
FIELD_COUNT
FIELD_LENGTH
MIN_FIELD_LENGTH
READ_ALL_FIELDS
WRITE_ALL_FIELDS
READ_MODIFY_WRITE_PROPORTION
REQUEST_DISTRIBUTION
MIN_SCANLENGTH
MAX_SCANLENGTH
SCAN_LENGTH_DISTRIBUTION
ZERO_PADDING
FIELD_NAME_PREFIX
MAX_EXECUTION_TIME
JVM_ARGS
YCSB_MEASUREMENT_TYPE)

# Kubernetes Setting
RECONFIG_OPTIONS="\
-DTESTCASE=${TESTCASE} \
-DINSTANCE_NUM=${INSTANCE_NUM} \
-DREDIS_NUMACTL_STRATEGY=${REDIS_NUMACTL_STRATEGY} \
-DCLIENT_COUNT=${CLIENT_COUNT} \
-DNUMA_NODE_FOR_REDIS_SERVER=${NUMA_NODE_FOR_REDIS_SERVER} \
-DHOST_NETWORK_ENABLE=${HOST_NETWORK_ENABLE} \
-DPERFORMANCE_PHASE_MODE=${PERFORMANCE_PHASE_MODE} \
-DREDIS_SERVER_IO_THREADS=${REDIS_SERVER_IO_THREADS} \
-DREDIS_SERVER_IO_THREADS_DO_READS=${REDIS_SERVER_IO_THREADS_DO_READS} \
-DREDIS_PERSISTENCE_POLICY=${REDIS_PERSISTENCE_POLICY} \
-DREDIS_APPENDFSYNC_MODE=${REDIS_APPENDFSYNC_MODE} \
-DREDIS_RDB_SECONDS=${REDIS_RDB_SECONDS} \
-DREDIS_RDB_CHANGES=${REDIS_RDB_CHANGES} \
-DREDIS_SERVER_IO_THREADS_CPU_AFFINITY=${REDIS_SERVER_IO_THREADS_CPU_AFFINITY} \
-DREDIS_EVICTION_POLICY=${REDIS_EVICTION_POLICY} \
-DWORKLOAD_FILE=${WORKLOAD_FILE} \
-DTHREADS=${THREADS} \
-DRECORD_COUNT=${RECORD_COUNT} \
-DOPERATION_COUNT=${OPERATION_COUNT} \
-DINSERT_START=${INSERT_START} \
-DINSERT_COUNT=${INSERT_COUNT} \
-DINSERT_ORDER=${INSERT_ORDER} \
-DREAD_PROPORTION=${READ_PROPORTION} \
-DUPDATE_PROPORTION=${UPDATE_PROPORTION} \
-DINSERT_PROPORTION=${INSERT_PROPORTION} \
-DSCAN_PROPORTION=${SCAN_PROPORTION} \
-DTARGET=${TARGET} \
-DFIELD_COUNT=${FIELD_COUNT} \
-DFIELD_LENGTH=${FIELD_LENGTH} \
-DMIN_FIELD_LENGTH=${MIN_FIELD_LENGTH} \
-DREAD_ALL_FIELDS=${READ_ALL_FIELDS} \
-DWRITE_ALL_FIELDS=${WRITE_ALL_FIELDS} \
-DREAD_MODIFY_WRITE_PROPORTION=${READ_MODIFY_WRITE_PROPORTION} \
-DREQUEST_DISTRIBUTION=${REQUEST_DISTRIBUTION} \
-DMIN_SCANLENGTH=${MIN_SCANLENGTH} \
-DMAX_SCANLENGTH=${MAX_SCANLENGTH} \
-DSCAN_LENGTH_DISTRIBUTION=${SCAN_LENGTH_DISTRIBUTION} \
-DZERO_PADDING=${ZERO_PADDING} \
-DFIELD_NAME_PREFIX=${FIELD_NAME_PREFIX} \
-DMAX_EXECUTION_TIME=${MAX_EXECUTION_TIME} \
-DJVM_ARGS=${JVM_ARGS} \
-DYCSB_MEASUREMENT_TYPE=${YCSB_MEASUREMENT_TYPE}"

JOB_FILTER="name=benchmark"
. "$DIR/../../script/validate.sh"

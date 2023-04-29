#!/bin/bash -e

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
SELECT_NUMA_NODE=${SELECT_NUMA_NODE:='0'}                           ## if NUMACTL_OPTION was set to 2, this is the selected numa node; for other NUMACTL_OPTION, this is meaningless
CORES=${CORES:=''}                                                  ## if NUMACTL_OPTION was set to 2, this is the selected cores on selected numa node, like 0, or 0,1 , or 0-7
YCSB_CORES=${YCSB_CORES:=''}                                        ## this is the selected cores bounded with ycsb instances. you can set it like 32-63
CUSTOMER_NUMAOPT_CLIENT=${CUSTOMER_NUMAOPT_CLIENT:=""}              ## customer numactl parameters for YCSB
CUSTOMER_NUMAOPT_SERVER=${CUSTOMER_NUMAOPT_SERVER:=""}              ## customer numactl parameters for MongoDB
                                                                    #### customer parameters take effect in single-node scenarios, these two are the most significiant parameters 
                                                                    #### and will overwrite all numa-related parameters. You can set it as using `numactl` dirctly
                                                                    #### e.g. CUSTOMER_NUMAOPT_CLIENT="-N 1 -M 1"; CUSTOMER_NUMAOPT_SERVER="-N 0 -M 0"
MONGO_DISK_DATABASE_ACCESS=${MONGO_DISK_DATABASE_ACCESS:=false}     ## Mongodb has to access disk for the database beacause memory is saturated by stress-ng
                                                                    ##### database is in memory when this value is False
DB_HUGEPAGE_STATUS=${DB_HUGEPAGE_STATUS:=false} ## enable/disable transparent hugepages
NETWORK_RPS_TUNE_ENABLE=${NETWORK_RPS_TUNE_ENABLE:=false}           ## RPS tuning flag on aws cloud. m6i.32xlarge

# ycsb params
WORKLOAD_FILE=${WORKLOAD_FILE:=90Read10Update}
THREADS=${THREADS:=10}
RECORD_COUNT=${RECORD_COUNT:=4000000}
OPERATION_COUNT=${OPERATION_COUNT:=4000000}
INSERT_START=${INSERT_START:=0}
INSERT_COUNT=${INSERT_COUNT:=0}
READ_PROPORTION=${READ_PROPORTION:=0.95}
UPDATE_PROPORTION=${UPDATE_PROPORTION:=0.05}
INSERT_PROPORTION=${INSERT_PROPORTION:=0}
SCAN_PROPORTION=${SCAN_PROPORTION:=0}
TARGET=${TARGET:=0}
FIELD_COUNT=${FIELD_COUNT:=10}
FIELD_LENGTH=${FIELD_LENGTH:=100}
MIN_FIELD_LENGTH=${MIN_FIELD_LENGTH:=1}
READ_ALL_FIELDS=${READ_ALL_FIELDS:=true}
WRITE_ALL_FIELDS=${WRITE_ALL_FIELDS:=false}
READ_MODIFY_WRITE_PROPORTION=${READ_MODIFY_WRITE_PROPORTION:=0}
REQUEST_DISTRIBUTION=${REQUEST_DISTRIBUTION:=zipfian}
MIN_SCANLENGTH=${MIN_SCANLENGTH:=1}
MAX_SCANLENGTH=${MAX_SCANLENGTH:=1000}
SCAN_LENGTH_DISTRIBUTION=${SCAN_LENGTH_DISTRIBUTION:=uniform}
ZERO_PADDING=${ZERO_PADDING:=1}
INSERT_ORDER=${INSERT_ORDER:=hashed}
FIELD_NAME_PREFIX=${FIELD_NAME_PREFIX:=field}
MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:=180}
JVM_ARGS=${JVM_ARGS:='-XX:+UseNUMA'}
YCSB_MEASUREMENT_TYPE=${YCSB_MEASUREMENT_TYPE:=hdrhistogram}

# mongodb params
CACHE_SIZE_GB=${CACHE_SIZE_GB:=''}
JOURNAL_ENABLED=${JOURNAL_ENABLED:=false}
COLLECTIONCONFIG_BLOCKCOMPRESSOR=${COLLECTIONCONFIG_BLOCKCOMPRESSOR:=snappy}
DB_HOSTPATH=${DB_HOSTPATH:=''}
MONGODB_PERCENTAGE_DB_CACHE_DB=${MONGODB_PERCENTAGE_DB_CACHE_DB:=0.25}

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
fi

if [[ "$RUN_SINGLE_NODE" =~ "true" ]]; then
    CLIENT_COUNT=0
elif [ $CLIENT_COUNT -eq 0 ]; then
    RUN_SINGLE_NODE=true
fi

. "$DIR/../../script/overwrite.sh"

# maxSkew describes the degree to which Pods may be unevenly distributed
if [ $CLIENT_COUNT -ne 0 ]; then
    let MAX_SKEW=(CLIENT_SERVER_PAIR + CLIENT_COUNT - 1)/CLIENT_COUNT
else
    let MAX_SKEW=${CLIENT_SERVER_PAIR}
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
CORES 
SELECT_NUMA_NODE 
MAX_SKEW 
MAX_EXECUTION_TIME 
JVM_ARGS 
CONFIG_CENTER_PORT  
CACHE_SIZE_GB 
JOURNAL_ENABLED 
COLLECTIONCONFIG_BLOCKCOMPRESSOR 
TARGET 
DB_HOSTPATH 
TLS_FLAG 
NETWORK_RPS_TUNE_ENABLE 
MONGO_DISK_DATABASE_ACCESS 
DB_HUGEPAGE_STATUS 
YCSB_MEASUREMENT_TYPE 
MONGODB_PERCENTAGE_DB_CACHE_DB 
RUN_SINGLE_NODE 
CUSTOMER_NUMAOPT_CLIENT 
CUSTOMER_NUMAOPT_SERVER 
YCSB_CORES 
CLIENT_COUNT)

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DCLIENT_SERVER_PAIR=${CLIENT_SERVER_PAIR} \
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
-DMAX_SKEW=${MAX_SKEW} \
-DMAX_EXECUTION_TIME=${MAX_EXECUTION_TIME} \
-DJVM_ARGS=${JVM_ARGS} \
-DCONFIG_CENTER_PORT=${CONFIG_CENTER_PORT} \
-DCACHE_SIZE_GB=${CACHE_SIZE_GB} \
-DJOURNAL_ENABLED=${JOURNAL_ENABLED} \
-DCOLLECTIONCONFIG_BLOCKCOMPRESSOR=${COLLECTIONCONFIG_BLOCKCOMPRESSOR} \
-DTARGET=${TARGET} \
-DDB_HOSTPATH=${DB_HOSTPATH} \
-DTLS_FLAG=${TLS_FLAG} \
-DNETWORK_RPS_TUNE_ENABLE=${NETWORK_RPS_TUNE_ENABLE} \
-DMONGO_DISK_DATABASE_ACCESS=${MONGO_DISK_DATABASE_ACCESS} \
-DDB_HUGEPAGE_STATUS=${DB_HUGEPAGE_STATUS} \
-DYCSB_MEASUREMENT_TYPE=${YCSB_MEASUREMENT_TYPE} \
-DMONGODB_PERCENTAGE_DB_CACHE_DB=${MONGODB_PERCENTAGE_DB_CACHE_DB} \
-DRUN_SINGLE_NODE=${RUN_SINGLE_NODE} \
-DCUSTOMER_NUMAOPT_CLIENT=${CUSTOMER_NUMAOPT_CLIENT} \
-DCUSTOMER_NUMAOPT_SERVER=${CUSTOMER_NUMAOPT_SERVER} \
-DYCSB_CORES=${YCSB_CORES} \
-DCLIENT_COUNT=${CLIENT_COUNT}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"


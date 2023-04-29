#!/bin/bash -e

### workspace
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR/script/common.sh"

### General settings
RUN_SINGLE_NODE=${RUN_SINGLE_NODE:-false}
ENABLE_SOCKET_BIND=${ENABLE_SOCKET_BIND:-false}
SERVER_SOCKET_BIND_NODE=${SERVER_SOCKET_BIND_NODE:-""} # by default bind all nodes
SERVER_SOCKET_BIND_CORE_LIST=${SERVER_SOCKET_BIND_CORE_LIST:-""} # by default bind all core on the node
CLIENT_SOCKET_BIND_NODE=${CLIENT_SOCKET_BIND_NODE:-""} # by default bind all nodes
CLIENT_SOCKET_BIND_CORE_LIST=${CLIENT_SOCKET_BIND_CORE_LIST:-""} # by default bind all core on the node
ENABLE_MOUNT_DIR=${ENABLE_MOUNT_DIR:-true}
MOUNT_DIR=${MOUNT_DIR:-"/mnt/disk1"}
ENABLE_TUNING=${ENABLE_TUNING:-true}

### multi-node settings
ENABLE_RPSRFS_AFFINITY=${ENABLE_RPSRFS_AFFINITY:-true}
RPS_SOCK_FLOW_ENTRIES=${RPS_SOCK_FLOW_ENTRIES:-32768}
ENABLE_IRQ_AFFINITY=${ENABLE_IRQ_AFFINITY:-true}
EXCLUDE_IRQ_CORES=${EXCLUDE_IRQ_CORES:-false}
PLATFORM=${PLATFORM:-SPR}
DB_RUN_PLATFORM=${DB_RUN_PLATFORM:-"x86"}
if [[ "$PLATFORM" = "ARMv"* ]]; then
    DB_RUN_PLATFORM="arm64"
fi

### database settings
DB_TYPE=${1:-mysql}
DB_FS_TYPE=${2:-disk}
DB_HUGEPAGE_STATUS=${3:-off}
DB_VERSION=${4:-"8031"}
MYSQL_USECASE=${5:-"base"}
DEBUG=${DEBUG:-false}
DB_PORT=${DB_PORT:-3306}
if [[ "$DB_TYPE" == "mysql" ]]; then
    DB_PORT=3306
    case $MYSQL_USECASE in
        base )
            WORKLOAD_TAG=TF-HammerDBTPCC-MySQL-BASELINE
            ;;
        pdt )
            WORKLOAD_TAG=TF-HammerDBTPCC-MySQL-INFLEET
            ;;
        oss )
            WORKLOAD_TAG=TF-HammerDBTPCC-MySQL-DOWNSTREAM
            export MYSQL_MOUNT_PATH="/home/mysql/data"
            # mount to /home to prevent mysqld load this cnf since oss version
            # already have cnf
            export MYSQL_CONFIG_PATH="/home/mysql.cnf"
            ;;
    esac
elif [[ "$DB_TYPE" == "postgresql" ]]; then
    DB_PORT=5432
fi

### begin loading default parameters of database and hammerdb
if [[ "$DB_TYPE" == "mysql" ]]; then
    source "$DIR/script/params/mysql_param.sh"
    ENABLE_TUNING=false
    if [[ "$TESTCASE" = *"1n" ]]; then
        RUN_SINGLE_NODE=true
    fi
elif [[ "$DB_TYPE" == "postgresql" ]]; then
    source  "$DIR/script/params/postgresql_param.sh"
fi
source "$DIR/script/params/hammerdb_param.sh"
### end

### begin sale down parameters for gated test case
GATED=false
if [[ "${TESTCASE}" =~ ^test.*_gated$ ]]; then
    GATED=true
    DEBUG=true
    ENABLE_MOUNT_DIR=false # small data volume no need to mount directory for gated test
    if [[ "$PLATFORM" = "ARMv"* ]]; then
        RUN_SINGLE_NODE=false
        echo "Change RUN_SINGLE_NODE to false in multiplatform. HammerDB need run on x86_64, Mysql need run on arrch64."
    else
        RUN_SINGLE_NODE=true   # no need to create labels for gated test
    fi
    
    if [[ "$DB_TYPE" == "mysql" ]]; then
        scale_mysql_gated_params
    elif [[ "$DB_TYPE" == "postgresql" ]]; then
        scale_postgresql_gated_params
    fi
    scale_hammerdb_params_gated
fi
### end

### single node settings
if ${RUN_SINGLE_NODE:-false}; then
    SERVER_CORE_NEEDED_FACTOR=${SERVER_CORE_NEEDED_FACTOR:-0.9}
fi

### multi-node setttings
if ! ${RUN_SINGLE_NODE:-false}; then
    if [[ -z "$TPCC_HAMMER_NUM_VIRTUAL_USERS" ]]; then
        echo "Info: no virtual user specified, auto-gen by build thread count $TPCC_THREADS_BUILD_SCHEMA"
        algo=${TPCC_HAMMER_NUM_VIRTUAL_USERS_GEN_ALGORITHM:-"fixed"}
        algo_func=$(
            case $algo in
                baseline)
                    echo "get_baseline_vuser_list"
                    ;;
                advanced_binary_search)
                    echo "get_advanced_binarysearch_vuser_list"
                    ;;
                binary_search)
                    echo "get_binarysearch_vuser_list"
                    ;;
                *)
                    echo "get_fixed_vuser_list"
                    ;;
            esac
        )
        export TPCC_HAMMER_NUM_VIRTUAL_USERS="$($algo_func)"
    fi
    echo "TPCC_HAMMER_NUM_VIRTUAL_USERS=$TPCC_HAMMER_NUM_VIRTUAL_USERS"
fi
### end

### begin CPU request & limit
DB_CPU_REQUEST=${DB_CPU_REQUEST:-1}
### end

### Logs Setting
source "$DIR/../../script/overwrite.sh"

if ! ${ENABLE_TUNING:-true}; then
    ENABLE_RPSRFS_AFFINITY=false
    ENABLE_IRQ_AFFINITY=false
fi

### begin caculate hugepages depends on database buffer pool size
if [[ "$DB_HUGEPAGE_STATUS" == "on" ]]; then
    source "$DIR/script/setup_hugepages.sh" "${DB_TYPE}"
fi
### end

### begin CPU request & limit, TPCC_THREADS_BUILD_SCHEMA will be overwrited by test-config
DB_CPU_LIMIT=${DB_CPU_LIMIT:-$TPCC_THREADS_BUILD_SCHEMA}
### end

### if MYSQL_INNODB_BUFFER_POOL_SIZE is not set, set it by 1GB per vCPU up to 64.
if ! [ $MYSQL_INNODB_BUFFER_POOL_SIZE ]; then
    MYSQL_INNODB_BUFFER_POOL_SIZE=$DB_CPU_LIMIT;
    [ $MYSQL_INNODB_BUFFER_POOL_SIZE -gt 64 ] && MYSQL_INNODB_BUFFER_POOL_SIZE=64;
    export MYSQL_INNODB_BUFFER_POOL_SIZE="${MYSQL_INNODB_BUFFER_POOL_SIZE}G"
fi

### if PG_SHARED_BUFFERS is not set, set it by 1GB per vCPU up to 64.
if ! [ $PG_SHARED_BUFFERS ]; then
    PG_SHARED_BUFFERS=$DB_CPU_LIMIT;
    [ $PG_SHARED_BUFFERS -gt 64 ] && PG_SHARED_BUFFERS=64;
    export PG_SHARED_BUFFERS="${PG_SHARED_BUFFERS}GB"
fi

### begin list all keys of parameters
## encapsulate and export key=value as envrionments
TESTCASE_KEYS="DEBUG GATED DB_FS_TYPE DB_HUGEPAGE_STATUS RUN_SINGLE_NODE ENABLE_SOCKET_BIND SERVER_SOCKET_BIND_NODE CLIENT_SOCKET_BIND_NODE SERVER_SOCKET_BIND_CORE_LIST CLIENT_SOCKET_BIND_CORE_LIST"
if ${RUN_SINGLE_NODE:-false} && ${ENABLE_SOCKET_BIND:-true}; then
    TESTCASE_KEYS="$(concat_params $TESTCASE_KEYS "SERVER_CORE_NEEDED_FACTOR")"
elif ! ${RUN_SINGLE_NODE:-false}; then
    TESTCASE_KEYS="$(concat_params $TESTCASE_KEYS "ENABLE_IRQ_AFFINITY" "ENABLE_RPSRFS_AFFINITY" "RPS_SOCK_FLOW_ENTRIES")"
    if ${ENABLE_SOCKET_BIND:-true}; then
        TESTCASE_KEYS="$(concat_params $TESTCASE_KEYS)"
    fi
fi

DB_KEYS="DB_TYPE DB_PORT DB_DATASIZE_OF_WAREHOUSE_RATIO DB_BUFFERSIZE_OF_DATASIZE_RATIO DB_CPU_REQUEST DB_CPU_LIMIT DB_RUN_PLATFORM ENABLE_MOUNT_DIR DB_VERSION ENABLE_TUNING MYSQL_USECASE"
if ${ENABLE_MOUNT_DIR:-true}; then
    DB_KEYS="$(concat_params $DB_KEYS "MOUNT_DIR")"
fi

HAMMERDB_KEYS="$(env |awk -F= '/^TPCC_/{printf $1" "}')"
if [[ "$DB_TYPE" == "mysql" ]]; then
    MYSQL_KEYS="$(env |awk -F= '/^MYSQL_/{printf $1" "}')"
    DB_KEYS="$(concat_params $DB_KEYS $MYSQL_KEYS)"
elif [[ "$DB_TYPE" == "postgresql" ]]; then
    POSTGRESQL_KEYS="$(env |awk -F= '/^PG_/{printf $1" "}')"
    DB_KEYS="$(concat_params $DB_KEYS $POSTGRESQL_KEYS)"
fi
if [[ "$DB_HUGEPAGE_STATUS" == "on" ]]; then
    DB_KEYS="$(concat_params $DB_KEYS "DB_HUGEPAGES_2MI" "DB_HUGEPAGES")"
fi
ALL_KEYS="$(concat_params $TESTCASE_KEYS $DB_KEYS $HAMMERDB_KEYS)"
### end

### EVENT_TRACE_PARAMS for collecting emon data
EVENT_TRACE_PARAMS="roi,Taking start Transaction Count,Taking end Transaction Count"

### Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
if ${DEBUG:-false}; then
    echo
    echo "WORKLOAD_PARAMS=$WORKLOAD_PARAMS" |sed -e "s/;/\\n/g"
fi

### Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

### Kubernetes Setting
RECONFIG_OPTIONS=$(eval echo "$(k8s_settings $ALL_KEYS)")
if ${DEBUG:-false}; then
    echo
    echo "RECONFIG_OPTIONS=$RECONFIG_OPTIONS" |sed -e "s/ /\\n/g"
fi
JOB_FILTER="job-name=benchmark"

### Script Setting
SCRIPT_ARGS="$DB_TYPE"
source "$DIR/../../script/validate.sh"

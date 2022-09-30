#!/bin/bash -e

### 1000 warehouses (~100GB size)
export DB_DATASIZE_OF_WAREHOUSE_RATIO=${DB_DATASIZE_OF_WAREHOUSE_RATIO:-0.1}
export DB_BUFFERSIZE_OF_DATASIZE_RATIO=${DB_BUFFERSIZE_OF_DATASIZE_RATIO:-1.0}

function to_bytes() {
    str_value="$1";
    if [[ -z "$str_value" ]];then
        echo "0"
    fi
    int_value=$(echo "$str_value"|grep -o '^[0-9]\+')
    if [[ "$str_value" =~ [tT][bB]* ]]; then
        echo "$(( int_value*1024*1024*1024*1024 ))"
    elif [[ "$str_value" =~ [gG][bB]* ]]; then
        echo "$(( int_value*1024*1024*1024 ))"
    elif [[ "$str_value" =~ [mM][bB]* ]]; then
        echo "$(( int_value*1024*1024 ))"
    elif [[ "$str_value" =~ [Kk][bB]* ]]; then
        echo "$(( int_value*1024 ))"
    else
      echo "$int_value"
    fi
}

DATASIZE_GB=$(echo "$TPCC_NUM_WAREHOUSES $DB_DATASIZE_OF_WAREHOUSE_RATIO" |awk '{print $1 * $2}')
EXPECTED_DB_BUFFER_GB=$(echo "$DATASIZE_GB $DB_BUFFERSIZE_OF_DATASIZE_RATIO" |awk '{print $1 * $2}')

DATASIZE_BYTES=$(to_bytes "${DATASIZE_GB}G")
EXPECTED_DB_BUFFER_BYTES=$(to_bytes "${EXPECTED_DB_BUFFER_GB}G")

DB_TYPE=${1:-mysql}
if [[ "$DB_TYPE" == "mysql" ]]; then
    CFG_DB_BUFFER_BYTES=$(to_bytes "$MYSQL_INNODB_BUFFER_POOL_SIZE")
fi

ACTUAL_DB_BUFFER_BYTES=$CFG_DB_BUFFER_BYTES
if [[ "$CFG_DB_BUFFER_BYTES" -lt "$EXPECTED_DB_BUFFER_BYTES" ]]; then
    echo "Warning: the configured buffer pool size $CFG_DB_BUFFER_BYTES is lower than expected $EXPECTED_DB_BUFFER_BYTES, use the expected size"
    ACTUAL_DB_BUFFER_BYTES=$EXPECTED_DB_BUFFER_BYTES
fi

HUGEPAGE_BYTES=$ACTUAL_DB_BUFFER_BYTES
ONE_GB=$(( 1 * 1024 * 1024 * 1024 ))
if [[ "$HUGEPAGE_BYTES" -lt "$ONE_GB" ]]; then
    HUGEPAGE_BYTES=$ONE_GB # at least 1GB
fi

HUGEPAGE_BYTES="$(get_min_nth_powerof2 $HUGEPAGE_BYTES)"

HUGEPAGES_GB=$(( HUGEPAGE_BYTES / 1024 / 1024 / 1024 ))
export DB_HUGEPAGES_2MI="${HUGEPAGES_GB}Gi"

PER_HUGEPAGES_2MI_BYTES=$(( 2 * 1024 * 1024 ))
export DB_HUGEPAGES=$(( HUGEPAGE_BYTES / PER_HUGEPAGES_2MI_BYTES ))

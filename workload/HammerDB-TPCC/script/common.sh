#!/bin/bash -e

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

## return a virtual user list concated by '_' 
## caculated based on cpu cores
function get_baseline_vuser_list() {
    num_cpus=${TPCC_THREADS_BUILD_SCHEMA:-128}
    num_logical_cores="$num_cpus"
    maxRange="$(echo "1.5 * $num_logical_cores" |bc |awk '{print int($0)}')"
    minRange=1
    hammer_users_list=()
    hammer_users_list+=("$num_cpus")
    loop=0
    step=-6
    step_adjust=1
    while [[ $loop -lt 2 ]]; do
        index=0
        while [[ "$index" -lt 4 ]]; do
            if [[ "$index" -eq 2 ]]; then
                (( step = (step + step_adjust) * 2 ))
            fi
            (( num_logical_cores += step ))
            if [[ "$num_logical_cores" -ge "$minRange" && "$num_logical_cores" -le "$maxRange" ]]; then
                hammer_users_list+=("$num_logical_cores")
            fi
            (( index += 1 ))
        done
            (( loop += 1 ))
            step=6
            step_adjust=-1
            (( num_logical_cores=num_cpus ))
    done

    if [[ ! " ${hammer_users_list[*]} " =~ ${maxRange} ]]; then
        hammer_users_list+=("$maxRange")
    fi
    sorted_list=$(echo "${hammer_users_list[@]}" | xargs -n1 | sort -n | xargs)
    echo "${sorted_list// /_}"
}

## return a fixed vuser list with fixed steps TPCC_VUSERS_STEPS(by default 8)
## example: 
## TPCC_THREADS_BUILD_SCHEMA=128
## TPCC_VUSERS_FLOAT_FACTOR=0.1
## TPCC_VUSERS_STEPS=4
## return list: 112_116_120_124_128_132_136_140_144
function get_fixed_vuser_list() {
    TPCC_THREADS_BUILD_SCHEMA=${TPCC_THREADS_BUILD_SCHEMA:-128}
    TPCC_VUSERS_STEPS=${TPCC_VUSERS_STEPS:-4}
    TPCC_VUSERS_FLOAT_FACTOR=${TPCC_VUSERS_FLOAT_FACTOR:-0.1}
    LOW=$(echo "$TPCC_THREADS_BUILD_SCHEMA $TPCC_VUSERS_FLOAT_FACTOR" |awk '{print int($1 - $1 * $2)}')
    HIGH=$(echo "$TPCC_THREADS_BUILD_SCHEMA $TPCC_VUSERS_FLOAT_FACTOR" |awk '{print int($1 + $1 * $2)}')
    MID=$TPCC_THREADS_BUILD_SCHEMA
    results=()
    results+=($MID)
    temp=$MID
    while [[ true ]]
    do
        temp=$((temp - TPCC_VUSERS_STEPS))
        results+=($temp)
        if [[ "$temp" -lt "$LOW" ]]; then
            break
        fi
    done
    sorted_results=$(echo "${results[@]}" | xargs -n1 | sort -n | xargs)
    temp=$MID
    while [[ true ]]
    do
        temp=$((temp + TPCC_VUSERS_STEPS))
        sorted_results+=($temp)
        if [[ "$temp" -gt "$HIGH" ]]; then
            break
        fi
    done
    echo "${sorted_results[@]}"|tr ' ' '_'
}

## return a binary search virtual user list between start and end
## example: 
## TPCC_THREADS_BUILD_SCHEMA: 128
## TPCC_HAMMER_NUM_VIRTUAL_USERS: 115_121_124_126_128_134_137_138_139_140_140
function get_binarysearch_vuser_list() {
    TPCC_THREADS_BUILD_SCHEMA=${TPCC_THREADS_BUILD_SCHEMA:-128}
    TPCC_VUSERS_FLOAT_FACTOR=${TPCC_VUSERS_FLOAT_FACTOR:-0.1}
    LOW=$(echo "$TPCC_THREADS_BUILD_SCHEMA $TPCC_VUSERS_FLOAT_FACTOR" |awk '{print int($1 - $1 * $2)}')
    HIGH=$(echo "$TPCC_THREADS_BUILD_SCHEMA $TPCC_VUSERS_FLOAT_FACTOR" |awk '{print int($1 + $1 * $2)}')
    results=()
    function binary_list(){
        low=$1
        high=$2
        mid=$(echo "$low $high"|awk '{printf("%.f\n", ($1+$2) / 2)}') # ceil
        if [[ $low -eq $mid ]]; then
            return
        fi
        results+=($mid)
        binary_list $mid $high
    }
    MID=$(echo "$LOW $HIGH"|awk '{printf("%.f\n", ($1+$2) / 2)}') # ceil
    results+=($LOW)
    binary_list $LOW $(( MID - 1 ))
    results+=($MID)
    binary_list $(( MID + 1 )) $HIGH
    results+=($HIGH)

    echo "${results[@]}"|tr ' ' '_' # format concat with "_"
}

## return a binary search virtual user list between start and end
## which will skip elements which abs(list[i+...k] - list[i]) < TPCC_VUSERS_STEPS
## example: 
## TPCC_THREADS_BUILD_SCHEMA=128
## TPCC_VUSERS_STEPS=4
## return list: 112_116_120_124_128_132_136_140_144
function get_advanced_binarysearch_vuser_list() {
    TPCC_VUSERS_STEPS=${TPCC_VUSERS_STEPS:-4}
    BINARY_VUSER_LIST=$(get_binarysearch_vuser_list)
    results=()
    for i in $(echo "$BINARY_VUSER_LIST" |tr '_' ' ')
    do 
        results+=($i)
    done

    ### begin to skip elements which difference less than steps
    HEAD=${results[0]}
    final_results+=($HEAD) # add the first element
    LEN=${#results[@]}
    TAIL_POS=$((LEN - 1))
    for((i=0;i< TAIL_POS;))
    do
        j=$((i+1))
        found=false
        for((;j< TAIL_POS;j++))
        do
            diff=$(( ${results[$j]} - ${results[$i]} ))
            diff=${diff#-} #abs
            if [[ $diff -ge $TPCC_VUSERS_STEPS ]]; then
                found=true
                break
            fi
        done
        if $found; then
            final_results+=(${results[$j]})
            i=$j # next start position to compare
            continue
        fi
        i=$((i+1))
    done
    final_results+=(${results[$TAIL_POS]}) # add the last element
    echo "${final_results[@]}"|tr ' ' '_' # format concat with "_"
}

## get min nearest to number of 2^N greater than input argument
## 
## e.g.:
## input arg <= 2,     return 2
## input arg is 3,     return 4=2^2
## input arg is 4,     return 4=2^2
## input arg is 5-7,   return 8=2^3
## input arg is 9-15,  return 16=2^4
## ...
function get_min_nth_powerof2() {
    num="$1"
    if [[ -z "$num" ]]; then
        num=0
    fi
    n=$(( num - 1 ))
    n=$(( n | (n >> 1) ))
    n=$(( n | (n >> 2) ))
    n=$(( n | (n >> 4) ))
    n=$(( n | (n >> 8) ))
    n=$(( n | (n >> 16) ))
    if [[ "$n" -lt 2 ]]; then
        echo 2
    else
        echo "$(( n + 1 ))"
    fi
}

#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

source "$DIR"/ai_common/libs/common.sh

start_check() {
    print_title "Precondition Check"

    precondition_check_result="passed"
}

print_check_result() {
    if [ $precondition_check_result == "passed" ]; then
        echo -e "--Precondition check result: PASSED"
        print_end
    else 
        echo -e "--Precondition check result: FAILED"
        print_end
        exit 1
    fi
}

# $1: mode, $2: minimal core number, $3: case mode
check_core_number_by_case_mode() {
    print_subtitle "Checking core number for case mode"
    MODE=$1
    MINI_CORE_NR=$2
    CASE_MODE=$3

    if [[ "${CASE_MODE}" =~ "${MODE}" ]]; then
        CORE_NR=$(cat /proc/cpuinfo | grep -c processor)
        echo -e "case mode: "$CASE_MODE
        echo -e "core number needs: "$MINI_CORE_NR
        echo -e "current core number: "$CORE_NR
        if [ $CORE_NR -lt $MINI_CORE_NR ]; then
            echo -e "\t[FAILED]"
            precondition_check_result="failed"
        else
            echo -e "\t[PASSED]"
        fi
    else
        echo -e "\t"
    fi
}

check_memory() {
    print_subtitle "Checking memory resources"
    local ret=0
    memory_needs=$1
    echo -e "memory needs(G): " $memory_needs
    memory_free=$(free -g | awk '/Mem:/{print $7}')
    echo -e "current available memory(G): " $memory_free
    if [ $memory_free -lt $memory_needs ]; then
        echo -e "\t[FAILED]"
        precondition_check_result="failed"
    else
        echo -e "\t[PASSED]"
    fi
}



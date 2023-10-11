#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

is_positive_int() {
    if [[ $1 =~ ^[1-9][0-9]* ]]; then 
        return 0
    else
        return 1
    fi
}

is_from_string_list() {
    string_list=$2
    for str in ${string_list[*]}; do 
        if [[ $str == $1 ]]; then
            return 0
        fi
    done
    return 1
}

# Check whether the input parameter is a positive integer or not. For example:
# VAR=123
# check_positive_integer $VAR
check_positive_integer() {
    if ! is_positive_int $1; then
        echo "The input parameter is illegal. Because $1 is not a positive integer."
        exit 1
    fi
}

# Check whether the input parameter is a positive integer or empty. For example:
# VAR=
# check_positive_integer $VAR
check_positive_integer_with_empty_value() {
    if [[ $1 == "" ]]; then
        return
    fi
    check_positive_integer $1
}

# Check whether the input parameter is from the input string list. For example:
# VAR="A"
# check_string "A B C" $VAR 
check_string() {
    string_list=$1
    if ! is_from_string_list $2 "${string_list[*]}"; then
        echo "The input parameter is illegal. Because $2 is not in ${string_list[*]}."
        exit 1
    fi
}

# Check whether the input parameter is from the input string list or empty value. For example:
# VAR=
# check_string "A B C" $VAR 
check_string_with_empty_value() {
    if [[ $2 == "" ]]; then
        return
    fi
    string_list=$1
    check_string "${string_list[*]}" $2 
}

# Check whether the input parameter is a positive integer or from the input string list. For example:
# VAR=64
# check_positive_integer_with_default_value "AUTO auto" $VAR 
check_positive_integer_or_string() {
    if ! is_positive_int $2; then
        string_list=$1
        if ! is_from_string_list $2 "${string_list[*]}"; then
            echo "The input parameter is illegal. Because $2 is not a positive integer and not from ( ${string_list[*]} )."
            exit 1
        fi
    fi
}

# Check whether the input parameter is a positive integer or from the input string list or empty. For example:
# VAR=
# check_positive_integer_with_default_value "AUTO auto" $VAR 
check_positive_integer_or_string_with_empty_value() {
    if [[ $2 == "" ]]; then
        return
    fi
    string_list=$1
    check_positive_integer_or_string "${string_list[*]}" $2 
}

ai_workload_parameter_check() {
    check_positive_integer $BATCH_SIZE
    check_positive_integer $CORES_PER_INSTANCE
    check_positive_integer $STEPS
    check_positive_integer_with_empty_value $INSTANCE_NUMBER
    check_string "inference training" $FUNCTION
    check_string "throughput latency accuracy" $MODE
    check_string "fixed flex" $INSTANCE_MODE
    check_string "avx_fp32 avx_bloat16 avx_int8 amx_fp32 amx_bf16 amx_bfloat16 amx_int8 float32 bfloat16 int8" $PRECISION
    check_string "real dummy" $DATA_TYPE
    check_string "True False" $WEIGHT_SHARING
    check_string_with_empty_value "gated pkm" $CASE_TYPE 
}
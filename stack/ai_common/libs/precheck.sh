#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/information.sh
source "$DIR"/ai_common/libs/precondition_check.sh
source "$DIR"/ai_common/libs/info.sh

# Precheck
function show_info() {
    start_show_info
    ALL_KEYS=$1
    print_tested_params $ALL_KEYS
    print_lscpu
    end_show_info
}

function precondition_check() {
    start_check
    total_batch_size=$(( $1 * $2 ))
    memory_needs=$(( $total_batch_size / 100 ))
    check_memory $memory_needs
    print_check_result
}

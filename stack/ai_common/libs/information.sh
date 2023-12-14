#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

source "$DIR"/ai_common/libs/common.sh

start_show_info() {
    print_title "Show Info"
}

end_show_info() {
    print_end
}

print_tested_params() {
    print_subtitle "Test Parameters Used"

    for i in "$@"; do
        echo -e $i": "${!i}
    done

    print_end
}

print_lscpu() {
    print_subtitle "Result of lscpu"

    lscpu

    print_end
}


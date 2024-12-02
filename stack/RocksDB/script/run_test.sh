#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [[ "$COMPRESSED" != "iaa" ]]; then
    ./db_bench_test_scaling.sh $COMPRESSED 0 1 ${TYPE} $KEY_SIZE $VALUE_SIZE $BLOCK_SIZE "$DB_CPU_LIMIT" $NUM_SOCKETS default $NUM_DISKS
else
    iax_dev_id="0cfe"
    num_iax=$(lspci -d:${iax_dev_id} | wc -l)
    num_sockets=$(lscpu | grep "Socket(s):" | awk '{print $2}')
    iaa_inst=$((num_iax/num_sockets*NUM_SOCKETS))
    if [[ $iaa_inst -gt 0 ]]; then
        ./db_bench_test_scaling.sh $COMPRESSED $iaa_inst 128 ${TYPE} $KEY_SIZE $VALUE_SIZE $BLOCK_SIZE "$DB_CPU_LIMIT" $NUM_SOCKETS default $NUM_DISKS
    else
        echo "There is no IAA device on host."
    fi
fi
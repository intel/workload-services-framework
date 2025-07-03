#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function parser_ip_by_domain(){
    ip=`host $1|awk '{print $NF}'`
    until check_ip ${ip} 
    do
        sleep 2
        ip=`host $1|awk '{print $NF}'`
    done
    echo $ip
}

function check_ip(){
        IP=$@
        VALID_CHECK=$(echo $IP|awk -F. '$1 ~ /^[0-9.]+$/ && $2 ~ /^[0-9.]+$/ && $3 ~ /^[0-9.]+$/ && $4 ~ /^[0-9.]+$/ && $1<=255 && $2<=255 && $3<=255 && $4<=255 {print "yes"}')
        if [[ $VALID_CHECK == "yes" ]]; then
                return 0
        else
                return 1
        fi
}
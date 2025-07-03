#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
echo "Starting Doris FE..."
source ./libs.sh

ip=`parser_ip_by_domain ${K_POD_NAME}.doris-fe-service`
echo "get ${K_POD_NAME} ip: ${ip}"
priority_networks=`ip a |grep ${ip} |awk '{print $2}'`

echo "priority_networks = ${priority_networks}" >> conf/fe.conf

bin/start_fe.sh --daemon
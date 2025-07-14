#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
echo "Starting Doris BE..."

source ./libs.sh

ip=`parser_ip_by_domain ${K_POD_NAME}.doris-be-service`
echo "get ${K_POD_NAME} ip: ${ip}"
priority_networks="${ip}/32"


echo "enable_storage_vectorization = true" >> conf/be.conf
echo "enable_low_cardinality_optimize = true" >> conf/be.conf
echo "priority_networks = ${priority_networks}" >> conf/be.conf

bin/start_be.sh --daemon
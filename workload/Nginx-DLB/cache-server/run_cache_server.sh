#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DLB_ACC=${DLB_ACC:-"disable"}
LIBDLB_LOCAL_PATH=${LIBDLB_LOCAL_PATH:-"/dlb/libdlb/"}
CACHE_SERVER_WORKER=${CACHE_SERVER_WORKER:-"1"}
CACHE_SERVER_CORE=${CACHE_SERVER_CORE:-"1"}
FILE_SIZE=${FILE_SIZE:-"1MB"}
USE_KUBERNETES_SERVICE=${USE_KUBERNETES_SERVICE:-"true"}
if [ "$USE_KUBERNETES_SERVICE" = "true" ]; then
  CONTENT_SERVER_IP="nginx-content-server-service"
  CACHE_SERVER_IP="nginx-cache-server-service"
else
  CONTENT_SERVER_IP=${CONTENT_SERVER_IP:-"127.0.0.1"}
  CACHE_SERVER_IP=${CACHE_SERVER_IP:-"127.0.0.1"}
fi

function patch_nginx_config_file() {
    sed -i "s|CACHE_SERVER_IP|${CACHE_SERVER_IP}|" $1
    sed -i "s|CACHE_SERVER_WORKER|${CACHE_SERVER_WORKER}|" $1
    sed -i "s|CONTENT_SERVER_IP|${CONTENT_SERVER_IP}|" $1
    mv $1 /etc/nginx/nginx.conf
}

if [[ $FILE_SIZE == "10KB" ]]; then
  patch_nginx_config_file /etc/nginx/cache_nginx_10KB.conf
elif [[ $FILE_SIZE == "100KB" ]]; then
  patch_nginx_config_file /etc/nginx/cache_nginx_100KB.conf
elif [[ $FILE_SIZE == "1MB" ]]; then
  patch_nginx_config_file /etc/nginx/cache_nginx_1MB.conf
elif [[ $FILE_SIZE == "mix" ]]; then
  patch_nginx_config_file /etc/nginx/cache_nginx_mix.conf
fi

if [[ $DLB_ACC == "enable" ]]; then
  Cache_Server_Cmd="LD_LIBRARY_PATH=${LIBDLB_LOCAL_PATH} taskset -c ${CACHE_SERVER_CORE} /sbin/nginx -c /etc/nginx/nginx.conf"
else
  Cache_Server_Cmd="taskset -c ${CACHE_SERVER_CORE} /sbin/nginx -c /etc/nginx/nginx.conf"
fi
echo Cache_Server_Cmd: ${Cache_Server_Cmd}
eval ${Cache_Server_Cmd}
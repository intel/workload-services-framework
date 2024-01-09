#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

CONTENT_SERVER_CORE=${CONTENT_SERVER_CORE:-"1"}
CONTENT_SERVER_WORKER=${CONTENT_SERVER_WORKER:-"127.0.0.1"}
FILE_SIZE=${FILE_SIZE:-"1MB"}
USE_KUBERNETES_SERVICE=${USE_KUBERNETES_SERVICE:-"true"}
if [ "$USE_KUBERNETES_SERVICE" = "true" ]; then
  CONTENT_SERVER_IP="nginx-content-server-service"
else
  CONTENT_SERVER_IP=${CONTENT_SERVER_IP:-"127.0.0.1"}
fi

function patch_nginx_config_file() {
  sed -i "s|CONTENT_SERVER_WORKER|${CONTENT_SERVER_WORKER}|" $1
  sed -i "s|CONTENT_SERVER_IP|${CONTENT_SERVER_IP}|" $1
  mv $1 /etc/nginx/nginx.conf
}

if [[ $FILE_SIZE == "10KB" ]]; then
  patch_nginx_config_file /etc/nginx/content_nginx_10KB.conf
  nohup python3 /http_obj_gen.py --host localhost --port 8888 > /dev/null 2> /dev/null &
elif [[ $FILE_SIZE == "100KB" ]]; then
  patch_nginx_config_file /etc/nginx/content_nginx_100KB.conf
  nohup python3 /http_obj_gen.py --host localhost --port 8889 > /dev/null 2> /dev/null &
elif [[ $FILE_SIZE == "1MB" ]]; then
  patch_nginx_config_file /etc/nginx/content_nginx_1MB.conf
  nohup python3 /http_obj_gen.py --host localhost --port 8890 > /dev/null 2> /dev/null &
elif [[ $FILE_SIZE == "mix" ]]; then
  patch_nginx_config_file /etc/nginx/content_nginx_mix.conf
  nohup python3 /http_obj_gen.py --host localhost --port 8888 > /dev/null 2> /dev/null &
  nohup python3 /http_obj_gen.py --host localhost --port 8889 > /dev/null 2> /dev/null &
  nohup python3 /http_obj_gen.py --host localhost --port 8890 > /dev/null 2> /dev/null &
fi

Content_Server_Cmd="taskset -c ${CONTENT_SERVER_CORE} /sbin/nginx -c /etc/nginx/nginx.conf"
echo Content_Server_Cmd: ${Content_Server_Cmd}
eval ${Content_Server_Cmd}
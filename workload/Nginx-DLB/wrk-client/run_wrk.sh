#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function output_summary() {
    for filename in $@; do
        echo ${filename} >> output.logs
        sed -i "s|Latency|${filename%.log}Latency|" ${filename}
        sed -i "s|90%|${filename%.log}90%|" ${filename}
        sed -i "s|99%|${filename%.log}99%|" ${filename}
        sed -i "s|Requests\/sec|${filename%.log}Requests\/sec|" ${filename}
        sed -i "s|Transfer\/sec|${filename%.log}Transfer\/sec|" ${filename}
        cat ${filename} >> output.logs
    done
}

function confirm_cache_server_ready() {
    status=1
    count=0
    while [ $status != 0 ]; do
      wrk -t 1 -c 10 -d 3s -s $1 -T 10s -L http://${CACHE_SERVER_IP}:$2
      count=$(( $count + 1 ))
      echo "count=${count}, waiting for server."
      if (( count > 200 )); then
        echo "Something went wrong, can not access to server. Exit."
        exit 3
      fi
      status=$?
      sleep 5
    done
}

ulimit -n 655350

WRK_CORE=${WRK_CORE:-"1"}
WRK_THREADS=${WRK_THREADS:-"1"}
FILE_SIZE=${FILE_SIZE:-"1MB"}
WRK_TEXT_CONNECTIONS=${WRK_TEXT_CONNECTIONS:-"100"}
WRK_AUDIO_CONNECTIONS=${WRK_AUDIO_CONNECTIONS:-"100"}
WRK_VIDEO_CONNECTIONS=${WRK_VIDEO_CONNECTIONS:-"100"}
WRK_DURATION=${WRK_DURATION:-"30"}
CACHE_SERVER_IP=${CACHE_SERVER_IP:-"127.0.0.1"}
CACHE_TYPE=${CACHE_TYPE:-memory}
USE_KUBERNETES_SERVICE=${USE_KUBERNETES_SERVICE:-"true"}

if [ "$USE_KUBERNETES_SERVICE" = "true" ]; then
  CACHE_SERVER_IP="nginx-cache-server-service"
else
  CACHE_SERVER_IP=${CACHE_SERVER_IP:-"127.0.0.1"}
fi

#if [ "$USE_KUBERNETES_SERVICE" = "true" ]; then
SLEEP_TIME=$(( WRK_DURATION + 60 ))
if [[ $FILE_SIZE == "10KB" ]]; then
  confirm_cache_server_ready /10ktext_query.lua 8080
  taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_TEXT_CONNECTIONS} -d ${WRK_DURATION}s -s /10ktext_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8080 2>&1 | tee 10KB.log &
  sleep ${SLEEP_TIME}s
  output_summary 10KB.log
elif [[ $FILE_SIZE == "100KB" ]]; then
  confirm_cache_server_ready /100kaudio_query.lua 8081
  taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_AUDIO_CONNECTIONS} -d ${WRK_DURATION}s -s /100kaudio_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8081 2>&1 | tee 100KB.log &
  sleep ${SLEEP_TIME}s
  output_summary 100KB.log
elif [[ $FILE_SIZE == "1MB" ]]; then
  confirm_cache_server_ready /video_query.lua 8082
  if [[ $CACHE_TYPE == "memory" ]]; then
    # warm up
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_VIDEO_CONNECTIONS} -d 300s -s /video_query_memory.lua -T 10s -L http://${CACHE_SERVER_IP}:8082
    # benchmark
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_VIDEO_CONNECTIONS} -d ${WRK_DURATION}s -s /video_query_memory.lua -T 10s -L http://${CACHE_SERVER_IP}:8082 2>&1 | tee 1MB.log &
  else
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_VIDEO_CONNECTIONS} -d ${WRK_DURATION}s -s /video_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8082 2>&1 | tee 1MB.log &
  fi
  sleep ${SLEEP_TIME}s
  output_summary 1MB.log
elif [[ $FILE_SIZE == "mix" ]]; then
  confirm_cache_server_ready /10ktext_query.lua 8080
  if [[ $CACHE_TYPE == "memory" ]]; then
    # warm up cache
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_VIDEO_CONNECTIONS} -d 300s -s /video_query_memory.lua -T 10s -L http://${CACHE_SERVER_IP}:8082 &
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_TEXT_CONNECTIONS} -d 300s -s /10ktext_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8080 2>&1 | tee 10KB.log &
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_AUDIO_CONNECTIONS} -d 300s -s /100kaudio_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8081 2>&1 | tee 100KB.log &
    sleep 301s
    # benchmark
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_TEXT_CONNECTIONS} -d ${WRK_DURATION}s -s /10ktext_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8080 2>&1 | tee 10KB.log &
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_AUDIO_CONNECTIONS} -d ${WRK_DURATION}s -s /100kaudio_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8081 2>&1 | tee 100KB.log &
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_VIDEO_CONNECTIONS} -d ${WRK_DURATION}s -s /video_query_memory.lua -T 10s -L http://${CACHE_SERVER_IP}:8082 2>&1 | tee 1MB.log &
  else
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_TEXT_CONNECTIONS} -d ${WRK_DURATION}s -s /10ktext_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8080 2>&1 | tee 10KB.log &
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_AUDIO_CONNECTIONS} -d ${WRK_DURATION}s -s /100kaudio_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8081 2>&1 | tee 100KB.log &
    taskset -c ${WRK_CORE} wrk -t ${WRK_THREADS} -c ${WRK_VIDEO_CONNECTIONS} -d ${WRK_DURATION}s -s /video_query.lua -T 10s -L http://${CACHE_SERVER_IP}:8082 2>&1 | tee 1MB.log &
  fi
  sleep ${SLEEP_TIME}s
  
  output_summary 10KB.log 100KB.log 1MB.log
fi
#fi

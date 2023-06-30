#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

NODE=${NODE:-1}
MODE=${MODE:-http}
NGINX_HOST=${NGINX_SERVICE_NAME:-nginx-server-service}

if [ $PORT ]; then
	echo generated $MODE URL $NGINX_HOST:$PORT
    URL=$MODE://$NGINX_HOST:$PORT
else
    URL=$MODE://$NGINX_HOST
fi

ulimit -v unlimited
ulimit -m unlimited
#ulimit -l unlimited
#ulimit -n unlimited
#ulimit -i unlimited
ulimit -s unlimited
ulimit -u unlimited

echo client will stress nginx server URL: $URL

NUSERS=${CONCURRENCY:-200}
#NTHREADS=${NTHREADS:-$(nproc)}

tmp1=$(echo $CLIENT_CPU_LISTS | cut -f2 -d "-")
tmp2=$(echo $CLIENT_CPU_LISTS | cut -f1 -d "-")
CLIENT_THREADS=`expr $tmp1 - $tmp2 + 1`

NTHREADS=${CLIENT_THREADS:-4}
DURATION=${DURATION:-60}

CLIENT_CPU_LISTS=${CLIENT_CPU_LISTS:-0-3}

if [ $NTHREADS -gt $NUSERS ]; then
  NTHREADS="$NUSERS"
fi

# client wait nginx server ready
wget_cur_wait_loop=0
while [ ! $NGINX_RESPONSE ] || [ $NGINX_RESPONSE -ne 200 ] ; 
do
  wget_cur_wait_loop=`expr $wget_cur_wait_loop + 1`

  if (( wget_cur_wait_loop > 10 )); then
    echo client wait for Nginx server $URL timeout;
    exit 3;
  fi

  echo $wget_cur_wait_loop wget_Waiting $URL...;sleep 3s; 
  NGINX_RESPONSE=$(wget --spider --server-response --no-check-certificate $URL 2>&1 | awk '/^  HTTP/{print $2}')
done
echo wget_waiting_nginx_server_available_done

echo taskset -c $CLIENT_CPU_LISTS wrk -t$NTHREADS -c$NUSERS -d${DURATION}s --timeout $(( DURATION * 2 ))s --latency $URL/index.html
taskset -c $CLIENT_CPU_LISTS wrk -t$NTHREADS -c$NUSERS -d${DURATION}s --timeout $(( DURATION * 2 ))s --latency $URL/index.html

echo wrk_test_done

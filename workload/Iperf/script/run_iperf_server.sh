#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

IPERF_VER=${IPERF_VER:-2}
PROTOCOL=${PROTOCOL:-TCP}
SERVER_POD_PORT=${SERVER_POD_PORT:-5201}
SERVER_CORE_LIST=${SERVER_CORE_LIST:-"2-5,6-9"}
SERVER_OPTIONS=${SERVER_OPTIONS:-""}
SERVER_POD_IP=${SERVER_POD_IP:-iperf-server-service}
PARALLEL_NUM=${PARALLEL_NUM:-8}
SERVER_PING_PORT=${SERVER_PING_PORT:-2399}

nc -l -p $SERVER_PING_PORT &

# iperf command line on server side
if [[ $IPERF_VER == "2" ]]; then
  SERVER_CMD="taskset -c ${SERVER_CORE_LIST} iperf -s -m -p ${SERVER_POD_PORT} -o output.logs"
else
  SERVER_CMD="taskset -c ${SERVER_CORE_LIST} iperf3 -s -p ${SERVER_POD_PORT} -A ${SERVER_CPU_NUM} -V"
fi
if [[ $PROTOCOL == "UDP" && $IPERF_VER == "2" ]]; then
  SERVER_CMD="$SERVER_CMD -u"
fi
SERVER_CMD="$SERVER_CMD $SERVER_OPTIONS"
echo SERVER_CMD: $SERVER_CMD
nohup $SERVER_CMD > /dev/null 2>&1 &
sleep 5
echo 1 > /tmp/statuscheck

# wait for the ending of test
COUNT=0
if [ $PARALLEL_NUM -eq 1 ]; then
  KEY_WORD="Interval"
else
  KEY_WORD="SUM"
fi
while [ ! $TEST_FINISHED ] && [ $COUNT -ne 50 ];
do
  TEST_FINISHED=$(cat output.logs | awk '/'${KEY_WORD}'/{print $1}')
  sleep 10
  COUNT=$(( $COUNT + 1 ))
done

killall nc
if [ ! $TEST_FINISHED ]; then
  echo timeout while testing. no summary in log on server side.
  exit 3
fi 
killall iperf

# parse and modify the output when no summary in the log
if [ $PARALLEL_NUM -eq 1 ]; then
  line=$(grep -n pkts output.logs | cut -d ":" -f 1)
  sed -i "${line}s/\[[[:space:]][[:space:]]1]/\[SUM]/g" output.logs
fi

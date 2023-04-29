#!/bin/bash

IPERF_VER=${IPERF_VER:-2}
MODE=${MODE:-pod2pod}
PROTOCOL=${PROTOCOL:-TCP}

IPERF_SERVICE_NAME=${IPERF_SERVICE_NAME:-iperf-server-service}
SERVER_POD_PORT=${SERVER_POD_PORT:-5201}

CLIENT_CORE_LIST=${CLIENT_CORE_LIST:-"2-5,6-9"}
PARALLEL_NUM=${PARALLEL_NUM:-8}
CLIENT_TRANSMIT_TIME=${CLIENT_TRANSMIT_TIME:-30}
BUFFER_SIZE=${BUFFER_SIZE:-128K}
UDP_BANDWIDTH=${UDP_BANDWIDTH:-50M}
CLIENT_OPTIONS=${CLIENT_OPTIONS:-""}

if [[ $MODE == "pod2pod" ]]; then
  # get iperf server pod ip with nslookup
  LOOP_CNT=0
  NSLOOKUP_RESPONSE=0
  NOT_READY_STR="server can't find $IPERF_SERVICE_NAME"
  echo "$NOT_READY_STR"
  for ((LOOP_CNT = 0; LOOP_CNT < 200; LOOP_CNT ++))
  do
    NSLOOKUP_RESPONSE="$(nslookup $IPERF_SERVICE_NAME)"
    if [[ $NSLOOKUP_RESPONSE =~ $NOT_READY_STR ]]; then
      echo "$LOOP_CNT $NSLOOKUP_RESPONSE"
    else
      echo "nslookup ready"
      echo "NSLOOKUP_RESPONSE: $NSLOOKUP_RESPONSE"
      break
    fi
    sleep 3
  done
  if [[ $NSLOOKUP_RESPONSE =~ $NOT_READY_STR ]]; then
    echo "nslookup not ready"
    exit 3
  fi
  IPERF_SERVER_POD_IP="$(echo "$NSLOOKUP_RESPONSE" | grep Address | tail -n 1 | awk '{print $2}')"
  echo "IPERF_SERVER_POD_IP $IPERF_SERVER_POD_IP"
  IPERF_SERVER=${IPERF_SERVER_POD_IP}
else
  IPERF_SERVER=${IPERF_SERVICE_NAME}
fi

if [[ $IPERF_VER == "2" ]]; then
  CLIENT_CMD="taskset -c ${CLIENT_CORE_LIST} iperf -c ${IPERF_SERVER} -p ${SERVER_POD_PORT} -t ${CLIENT_TRANSMIT_TIME} -m -P ${PARALLEL_NUM} -l ${BUFFER_SIZE}"
else
  CLIENT_CMD="taskset -c ${CLIENT_CORE_LIST} iperf3 -c ${IPERF_SERVER} -p ${SERVER_POD_PORT} -P ${PARALLEL_NUM} -V"
fi
if [[ $PROTOCOL == "UDP" && $IPERF_VER == "2" ]]; then
  CLIENT_CMD="$CLIENT_CMD -u -b ${UDP_BANDWIDTH}"
fi
CLIENT_CMD="$CLIENT_CMD $CLIENT_OPTIONS"

echo CLIENT_CMD=$CLIENT_CMD
$CLIENT_CMD
echo iperf test finished

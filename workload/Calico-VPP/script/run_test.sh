#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# # Get hardware configuraiton info from mount file
source /etc/network_env.conf

TREX_PORT_A_PCI=$dpdk_port2
TREX_PORT_B_PCI='dummy'
DPDK_PORT1_DESTMAC=$dpdk_port1_destmac_loopback
DPDK_PORT2_SRCMAC=$dpdk_port2_srcmac_loopback

# Prepare TRex configuration file
sed -i 's/TREX_PORT_A_PCI/'`echo $TREX_PORT_A_PCI`'/g' /etc/trex_cfg.yaml
sed -i 's/TREX_CORE_NUM/'`echo $TREX_CORE_NUM`'/g' /etc/trex_cfg.yaml

sed -i 's/DPDK_PORT1_DESTMAC/'`echo $DPDK_PORT1_DESTMAC`'/g' /etc/trex_cfg.yaml
sed -i 's/DPDK_PORT2_SRCMAC/'`echo $DPDK_PORT2_SRCMAC`'/g' /etc/trex_cfg.yaml

sed -i 's/MASTER_THREAD_ID/'`echo $MASTER_THREAD_ID`'/g' /etc/trex_cfg.yaml
sed -i 's/LATENCY_THREAD_ID/'`echo $LATENCY_THREAD_ID`'/g' /etc/trex_cfg.yaml

sed -i 's/TREX_THREADS/'`echo $TREX_THREADS`'/g' /etc/trex_cfg.yaml
### Start trex server as background process"
TREX_LOG=${TREX_LOG:-/trex.log}
WORK_DIR=$(pwd)
cd $TREX_HOME
nohup ./t-rex-64 --prom -i > "$TREX_LOG" 2>&1 &
TREX_SERVER_PID=$!
cd $WORK_DIR

function check_trex_server() {
  LISTENING_PORTS=($(ss -tlp |awk '/LISTEN/{print $4}'|awk -F ':' '{print $2}'))
  # At least 4500/4501/4507 ports listened by default
  if [[ "${#LISTENING_PORTS[@]}" -ge 3 ]]; then
    return 0
  fi
  return 1
}

#### Ensure trex server running
counter=0
TREX_MAX_RETRIES=${TREX_MAX_RETRIES:-10}
until check_trex_server ; do 
  counter=$(( counter + 1 ))
  echo "Waiting for trex server running..."
  if [[ $counter -ge $TREX_MAX_RETRIES ]]; then
    echo "Waiting for trex server running with max retres times: $counter, quit"
    cat $TREX_LOG
    exit 1
  fi
  sleep 3s
done
echo "Trex server getting started successfully"
echo "CalicoVPP_MTU: $MTU"
echo "TREX_PACKET_SIZE: $TREX_PACKET_SIZE"
echo "CalicoVPP_ENABLE_DSA: $ENABLE_DSA"
echo "L3FWD_POD_IP: $L3FWD_POD_IP"
echo "stream_num: $TREX_STREAM_NUM"

## Run trex L3 forward to send/recv packets"
/usr/local/bin/python3 $TREX_STL_DIR/trex-l3fwd.py \
--packet-size=${TREX_PACKET_SIZE:-4000} \
--duration=${TREX_DURATION:-30} \
--src=${TREX_SOURCE_IP:-"192.168.50.23"} \
--dst=${DEST_IP:-${L3FWD_POD_IP}} \
--stream-num=${TREX_STREAM_NUM:-1}

echo "packet-size=${TREX_PACKET_SIZE:-4000} duration=${TREX_DURATION:-30} src=${TREX_SOURCE_IP:-"192.168.50.23"} dst=${DEST_IP:-${L3FWD_POD_IP}} stream-num=${TREX_STREAM_NUM:-1}"

# /usr/local/bin/python3 $TREX_STL_DIR/trex-l3fwd.py -s 1024 -d 30
TEST_RC=$?

# Kill background trex server process
pkill -P $TREX_SERVER_PID || pkill -9 -P $TREX_SERVER_PID

# Exit with testcase result code
exit $TEST_RC

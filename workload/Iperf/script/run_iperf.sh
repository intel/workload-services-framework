#!/bin/bash

# calculate the cpu list
function cpu_list() {
  core_count=$(cat /proc/cpuinfo | grep processor | wc -l)
  used_phy_core_count=$(( $1/2 ))
  first_phy_core=0
  first_logic_core=$(( core_count/2 ))
  if [ $2 == "yes" ]; then
    used_phy_core_count=$1
    last_used_phy_core=$(( first_phy_core+$1-1 ))
    CPU_LIST="${first_phy_core}-${last_used_phy_core}"
  else
    used_phy_core_count=$(( $1/2 ))
    last_used_phy_core=$(( first_phy_core+$used_phy_core_count-1 ))
    last_used_logic_core=$(( first_logic_core+$used_phy_core_count-1 ))
    CPU_LIST="${first_phy_core}-${last_used_phy_core},${first_logic_core}-${last_used_logic_core}"
  fi
}

# check whether the input is valid
function input_core_count_check() {
  core_count=$(cat /proc/cpuinfo | grep processor | wc -l)
  if [[ $1 -gt $core_count ]]; then
    echo input invalid: core count is set to $1 but there are only $core_count cores on this machine.
    exit 3
  fi
}

if [[ $CLIENT_OR_SERVER == "client" ]]; then
  echo CLIENT_CORE_COUNT=$CLIENT_CORE_COUNT
  echo ONLY_USE_PHY_CORE=$ONLY_USE_PHY_CORE
  if [[ $CLIENT_CORE_LIST == "-1" ]]; then
    input_core_count_check $CLIENT_CORE_COUNT
    cpu_list $CLIENT_CORE_COUNT $ONLY_USE_PHY_CORE
    CLIENT_CORE_LIST=$CPU_LIST
  else
    CLIENT_CORE_LIST=$CLIENT_CORE_LIST
  fi
    
  echo CLIENT_CORE_LIST=$CLIENT_CORE_LIST
  . /run_iperf_client.sh
else
  echo SERVER_CORE_COUNT=$SERVER_CORE_COUNT
  echo ONLY_USE_PHY_CORE=$ONLY_USE_PHY_CORE
  if [[ $SERVER_CORE_LIST == "-1" ]]; then
    input_core_count_check $SERVER_CORE_COUNT
    cpu_list $SERVER_CORE_COUNT $ONLY_USE_PHY_CORE
    SERVER_CORE_LIST=$CPU_LIST
  else
    SERVER_CORE_LIST=$SERVER_CORE_LIST
  fi

  echo SERVER_CORE_LIST=$SERVER_CORE_LIST
  . /run_iperf_server.sh
fi

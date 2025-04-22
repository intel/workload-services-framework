#!/usr/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

REDIS_SERVICE=${REDIS_SERVICE}
CONFIG_CENTER_SERVICE=${CONFIG_CENTER_SERVICE}
CONFIG_CENTER_PORT=${CONFIG_CENTER_PORT}
INSTANCE_NUM=${INSTANCE_NUM}
REDIS_NUMACTL_STRATEGY=${REDIS_NUMACTL_STRATEGY}
NUMA_NODE_FOR_REDIS_SERVER=${NUMA_NODE_FOR_REDIS_SERVER}
REDIS_NATIVE_TRANSPORT_PORT=${REDIS_NATIVE_TRANSPORT_PORT}
PERFORMANCE_PHASE_MODE=${PERFORMANCE_PHASE_MODE}
CLIENT_COUNT=${CLIENT_COUNT}

WORKLOAD_FILE=${WORKLOAD_FILE}
y_threads=${THREADS}
y_recordcount=${RECORD_COUNT}
y_operationcount=${OPERATION_COUNT}
y_insertstart=${INSERT_START}
y_insertcount=${INSERT_COUNT}
y_insertorder=${INSERT_ORDER}
y_readproportion=${READ_PROPORTION}
y_updateproportion=${UPDATE_PROPORTION}
y_insertproportion=${INSERT_PROPORTION}
y_scanproportion=${SCAN_PROPORTION}
y_target=${TARGET}
y_fieldcount=${FIELD_COUNT}
y_fieldlength=${FIELD_LENGTH}
y_minfieldlength=${MIN_FIELD_LENGTH}
y_readallfields=${READ_ALL_FIELDS}
y_writeallfields=${WRITE_ALL_FIELDS}
y_readmodifywrite_proportion=${READ_MODIFY_WRITE_PROPORTION}
y_requestdistribution=${REQUEST_DISTRIBUTION}
y_minscanlength=${MIN_SCANLENGTH}
y_maxscanlength=${MAX_SCANLENGTH}
y_scanlengthdistribution=${SCAN_LENGTH_DISTRIBUTION}
y_zeropadding=${ZERO_PADDING}
y_fieldnameprefix=${FIELD_NAME_PREFIX}
y_maxexecutiontime=${MAX_EXECUTION_TIME}
y_jvm_args=${JVM_ARGS}
y_measurementtype=${YCSB_MEASUREMENT_TYPE}

function numa_set() {
  if [[ $CLIENT_COUNT == 0 ]]; then
    echo "SINGLE NODE SCENARIO"
    YCSB_NUMACTL_STRATEGY="numactl --cpunodebind=!${NUMA_NODE_FOR_REDIS_SERVER} --localalloc"
  else
    case $REDIS_NUMACTL_STRATEGY in
      0 | 1 | 2)
        YCSB_NUMACTL_STRATEGY=""
        ;;
      # 2)
      #   cpuset=$(cat /sys/devices/system/cpu/cpu${JOB_INDEX}/topology/thread_siblings_list)
      #   if [[ "$cpuset" == *","* ]]; then
      #     echo "SMT-ON MODE" 
      #     let core_index=$JOB_INDEX*2
      #     cpuset1=$(cat /sys/devices/system/cpu/cpu${core_index}/topology/thread_siblings_list)
      #     let core_index_next=${core_index}+1
      #     cpuset2=$(cat /sys/devices/system/cpu/cpu${core_index_next}/topology/thread_siblings_list)
      #     YCSB_NUMACTL_STRATEGY="numactl --physcpubind="$cpuset,$cpuset2" --localalloc"
      #   else
      #     echo "SMT-OFF MODE" 
      #     let core_index=$JOB_INDEX*4
      #     cpuset1=$(cat /sys/devices/system/cpu/cpu${core_index}/topology/thread_siblings_list)
      #     let core_index_next_1=$core_index+1
      #     let core_index_next_2=$core_index+2
      #     let core_index_next_3=$core_index+3
      #     new_cpuset="${core_index},${core_index_next_1}"
      #     new_cpuset2="${core_index_next_2},${core_index_next_3}"
      #     YCSB_NUMACTL_STRATEGY="numactl --physcpubind="$new_cpuset,$new_cpuset2" --localalloc"
      #   fi
      #   ;;
      *)
        YCSB_NUMACTL_STRATEGY=""
        ;;
    esac
  fi
}

function service_connection_check() {
  redis_counter=0
  service=$1
  port=$2
  until ((redis_counter >= 3)); do
      echo "$1 connection are stable for $redis_counter seconds"
      nc -z -w5 $service $port
      if [ $? -eq 0 ]; then
          ((redis_counter++))
      else
          redis_counter=0
      fi
      sleep 1
  done
}

function register_config_center() {
  config_center_service=$1
  config_center_port=$2
  job_index=$3
  echo "config center: SET benchmark$job_index benchmark$job_index"
  until redis-cli -h $config_center_service -p $config_center_port set benchmark$job_index benchmark$job_index; do
    echo "register benchmark$job_index to $config_center_service failed. Will continue to try to re-register"
  done
}

function sync_with_config_cneter() {
  config_center_service=$1
  config_center_port=$2
  until test $(redis-cli -h $config_center_service -p $config_center_port keys benchmark[0-9]* | wc -l) -eq $INSTANCE_NUM; do
    echo "there is $(redis-cli -h $config_center_service -p $config_center_port keys benchmark* | wc -l) load phase process have finished"
    sleep 0.2
  done
}

## prepare
### test network to config center service
service_connection_check $CONFIG_CENTER_SERVICE $CONFIG_CENTER_PORT
let CLIENT_NODE_INDEX=$(redis-cli -h $CONFIG_CENTER_SERVICE -p $CONFIG_CENTER_PORT incr client_node_index)-1
### test network to redis service
service_connection_check $REDIS_SERVICE ${REDIS_NATIVE_TRANSPORT_PORT}

## set parameters
### add non-empty variables to ycsb_params 
ycsb_params="-threads $y_threads"
for var in "y_operationcount" "y_recordcount" "y_fieldcount" "y_fieldlength" "y_minfieldlength" "y_readallfields" "y_writeallfields" "y_readproportion" "y_updateproportion" "y_insertproportion" "y_scanproportion" "y_readmodifywrite_proportion" "y_requestdistribution" "y_minscanlength" "y_maxscanlength" "y_scanlengthdistribution" "y_zeropadding" "y_fieldnameprefix" "y_measurementtype" "y_insertorder"; do
    if [ ! -z $(eval echo "\$$var") ]; then
        suffix_var="${var#y_}"
        ycsb_params="$ycsb_params -p $suffix_var=$(eval echo "\$$var")"
    fi
done
ycsb_params="$ycsb_params -p redis.host=${REDIS_SERVICE}"
### set ycsb parameters for load phase
ycsb_params_loadphase="$ycsb_params"
### set ycsb parameters for run phase
ycsb_params_runphase="$ycsb_params"
for var in "y_insertstart" "y_insertcount" "y_maxexecutiontime" "y_target" "y_jvm_args"; do
    if [ ! -z $(eval echo "\$$var") ]; then
        suffix_var="${var#y_}"
        if [[ $suffix_var == "target" ]]; then
            suffix_var=$(echo "$suffix_var" | sed 's/_/-/g')
            ycsb_params_runphase="$ycsb_params_runphase -$suffix_var $(eval echo "\$$var")"
        elif [[ $suffix_var == "jvm_args" ]]; then
            suffix_var=$(echo "$suffix_var" | sed 's/_/-/g')
            ycsb_params_runphase="$ycsb_params_runphase -$suffix_var=$(eval echo "\$$var")"
        else
            ycsb_params_runphase="$ycsb_params_runphase -p $suffix_var=$(eval echo "\$$var")"
        fi
    fi
done
echo "ycsb loadphase parameters: ${ycsb_params_loadphase}"
echo "ycsb runphase parameters: ${ycsb_params_runphase}"

## start benchmarking
### set ycsb numactl strategy
numa_set

### run
echo "[WARMUP PHASE]"

LOADPIDS=()
if [ "$CLIENT_COUNT" -ne 0 ]; then
  for ((i=1; i<=INSTANCE_NUM; i++)); do
    if [ $((i % CLIENT_COUNT)) -eq $CLIENT_NODE_INDEX ]; then
      let LOAD_JOB_INDEX=$(redis-cli -h $CONFIG_CENTER_SERVICE -p $CONFIG_CENTER_PORT incr load_job_index)-1
      let portindex=${REDIS_NATIVE_TRANSPORT_PORT}+${LOAD_JOB_INDEX}
      ${YCSB_NUMACTL_STRATEGY} /usr/src/ycsb/bin/ycsb load redis -s -P /usr/src/ycsb/workloads/${WORKLOAD_FILE} ${ycsb_params_loadphase} -p redis.port=${portindex} > benchmark_warmup_${LOAD_JOB_INDEX}.log &
      LOADPIDS+=($!)
    else
      continue
    fi
  done
else
  for ((i=1; i<=INSTANCE_NUM; i++)); do
    let LOAD_JOB_INDEX=$(redis-cli -h $CONFIG_CENTER_SERVICE -p $CONFIG_CENTER_PORT incr load_job_index)-1
    let portindex=${REDIS_NATIVE_TRANSPORT_PORT}+${LOAD_JOB_INDEX}
    ${YCSB_NUMACTL_STRATEGY} /usr/src/ycsb/bin/ycsb load redis -s -P /usr/src/ycsb/workloads/${WORKLOAD_FILE} ${ycsb_params_loadphase} -p redis.port=${portindex} > benchmark_warmup_${LOAD_JOB_INDEX}.log  &
    LOADPIDS+=($!)
  done
fi
errors=0
for PID in ${LOADPIDS[*]}; do
  wait $PID
  if [ $? -eq 0 ]; then
    register_config_center $CONFIG_CENTER_SERVICE $CONFIG_CENTER_PORT $RANDOM
    echo "Load Process with PID $PID was SUCCESSFUL."
  else
    echo "Load Process with PID $PID FAILED."
    errors=1
  fi
done
if [ $errors -eq 1 ]; then
  echo "exit"
  exit 1
fi

# sleep some time for split warmup phase and performance phase on time
sleep 30

### sync
sync_with_config_cneter $CONFIG_CENTER_SERVICE $CONFIG_CENTER_PORT
echo "[PERFORMANCE PHASE]"
echo "start region of interest"

RUNPIDS=()
if [ "$CLIENT_COUNT" -ne 0 ]; then
  for ((i=1; i<=INSTANCE_NUM; i++)); do
    if [ $((i % CLIENT_COUNT)) -eq $CLIENT_NODE_INDEX ]; then
      let RUN_JOB_INDEX=$(redis-cli -h $CONFIG_CENTER_SERVICE -p $CONFIG_CENTER_PORT incr run_job_index)-1
      let portindex=${REDIS_NATIVE_TRANSPORT_PORT}+${RUN_JOB_INDEX}
      if [[ "$PERFORMANCE_PHASE_MODE" == "load" ]]; then
        ${YCSB_NUMACTL_STRATEGY} /usr/src/ycsb/bin/ycsb load redis -s -P /usr/src/ycsb/workloads/${WORKLOAD_FILE} ${ycsb_params_loadphase} -p redis.port=${portindex} > benchmark_performance_${RUN_JOB_INDEX}.log &
        RUNPIDS+=($!)
      else
        ${YCSB_NUMACTL_STRATEGY} /usr/src/ycsb/bin/ycsb run redis -s -P /usr/src/ycsb/workloads/${WORKLOAD_FILE} ${ycsb_params_runphase} -p redis.port=${portindex} > benchmark_performance_${RUN_JOB_INDEX}.log &
        RUNPIDS+=($!)
      fi
    fi
  done
else
  for ((i=1; i<=INSTANCE_NUM; i++)); do
    let RUN_JOB_INDEX=$(redis-cli -h $CONFIG_CENTER_SERVICE -p $CONFIG_CENTER_PORT incr run_job_index)-1
    let portindex=${REDIS_NATIVE_TRANSPORT_PORT}+${RUN_JOB_INDEX}
    if [[ "$PERFORMANCE_PHASE_MODE" == "load" ]]; then
      ${YCSB_NUMACTL_STRATEGY} /usr/src/ycsb/bin/ycsb load redis -s -P /usr/src/ycsb/workloads/${WORKLOAD_FILE} ${ycsb_params_loadphase} -p redis.port=${portindex} &
      RUNPIDS+=($!)
    else
      ${YCSB_NUMACTL_STRATEGY} /usr/src/ycsb/bin/ycsb run redis -s -P /usr/src/ycsb/workloads/${WORKLOAD_FILE} ${ycsb_params_runphase} -p redis.port=${portindex} &
      RUNPIDS+=($!)
    fi
  done
fi
errors=0
for PID in ${RUNPIDS[*]}; do
  wait $PID
  if [ $? -eq 0 ]; then
    echo "Run Process with PID $PID was SUCCESSFUL."
  else
    echo "Run Process with PID $PID FAILED."
    errors=1
  fi
done
if [ $errors -eq 1 ]; then
  exit 1
fi

echo "end region of interest"
echo "BENCHMARK FINISHD"
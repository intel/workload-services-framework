#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -x

# export all of the options for env deployment,packed in benchmark_options and configuration_options
export $(echo ${BENCHMARK_OPTIONS//"-D"/""} | tr -t ';' '\n')
export $(echo ${CONFIGURATION_OPTIONS//"-D"/""} | tr -t ';' '\n')


# For SPDK process
SPDK_PRO_CPUMASK=${SPDK_PRO_CPUMASK:-"0x3F"}
SPDK_PRO_CPUCORE=${SPDK_PRO_CPUCORE:-"6"} # cpu core count will be used
SPDK_HUGEMEM=${SPDK_HUGEMEM:-"8192"} # MiB
BDEV_TYPE=${BDEV_TYPE:-"mem"} # memory bdev for test
DRIVE_PREFIX=${DRIVE_PREFIX:-"Nvme"}  # it's Nvme if we consider more drives. e.g. Nvme0, Nvme1
NVMeF_NS=""
NVMeF_NSID="1"
NVMeF_SUBSYS_SN="SPDKTGT001" # just hardcode for S/N
NVMeF_MAX_NAMESPACES=${NVMeF_MAX_NAMESPACES:-"8"}

DRIVE_NUM=${DRIVE_NUM:-"1"}

# For debug
SPDK_TRACE=${SPDK_TRACE:-"0"}

# For NVMe o TCP connection
TGT_TYPE=${TGT_TYPE:-"tcp"} # target is over tcp
TGT_ADDR=${TGT_ADDR:-"192.168.88.100"} # define the nvme-over-tcp tagert address, for TCP it's IP address.
TGT_SERVICE_ID=${TGT_SERVICE_ID:-"4420"} # for TCP, it's network IP PORT.
TGT_NQN=${TGT_NQN:-"nqn.2023-03.io.spdk:cnode"} # target nqn ID/name for discovery and connection.
ENABLE_DIGEST=${ENABLE_DIGEST:-"0"} # enable or not TCP transport digest

export TGT_ADDR_ARRAY=( $( echo ${TGT_ADDR} | tr -t ',' ' ' ) ) #(20.0.0.1,20.0.1.1,10.0.0.1,10.0.1.1) -> (20.0.0.1 20.0.1.1 10.0.0.1 10.0.1.1)
TGT_ADDR_NUM=${#TGT_ADDR_ARRAY[@]}  # the IP address count for TCP connection

# For NVMF TCP Transport configuration.
TP_IO_UNIT_SIZE=${TP_IO_UNIT_SIZE:-"131072"} #IO_UNIT_SIZE for create nvme over fabric transport, I/O unit size (bytes)
TP_MAX_QUEUE_DEPTH=${TP_MAX_QUEUE_DEPTH:-"128"}
TP_MAX_IO_QPAIRS_PER_CTRLR=${TP_MAX_IO_QPAIRS_PER_CTRLR:-"127"}
TP_IN_CAPSULE_DATA_SIZE=${TP_IN_CAPSULE_DATA_SIZE:-"4096"}
TP_MAX_IO_SIZE=${TP_MAX_IO_SIZE:-"131072"}
TP_NUM_SHARED_BUFFERS=${TP_NUM_SHARED_BUFFERS:-"8192"}
TP_BUF_CACHE_SIZE=${TP_BUF_CACHE_SIZE:-"32"}
TP_C2H_SUCCESS=${TP_C2H_SUCCESS:-"1"} # Add C2H success flag (or not) for data transfer, it's a optimization flag
TCP_TP_SOCK_PRIORITY=${TCP_TP_SOCK_PRIORITY:-"0"}

# Special config
ENABLE_DSA=${ENABLE_DSA:-"0"} # enable or disable DSA hero feature for IA paltform.


BASE_PATH=/opt
WORK_PATH=${BASE_PATH}/spdk
LOG_PATH=${BASE_PATH}/logs
rpc_py="${WORK_PATH}/scripts/rpc.py"


# utility_function definition

function killprocess() {
	# $1 = process pid
	if [ -z "$1" ]; then
		return 1
	fi

	if kill -0 $1; then
		if [ $(uname) = Linux ]; then
			process_name=$(ps --no-headers -o comm= $1)
		else
			process_name=$(ps -c -o command $1 | tail -1)
		fi
		if [ "$process_name" = "sudo" ]; then
			# kill the child process, which is the actual app
			# (assume $1 has just one child)
			local child
			child="$(pgrep -P $1)"
			echo "killing process with pid $child"
			kill $child
		else
			echo "killing process with pid $1"
			kill $1
		fi

		# wait for the process regardless if its the dummy sudo one
		# or the actual app - it should terminate anyway
		wait $1
	else
		# the process is not there anymore
		echo "Process with pid $1 is not found"
	fi
}

function clean_up() {
	echo "Clean up the nvme over fabric subsystem firstly"

	for i in $(seq 1 ${DRIVE_NUM}); do
		NQN=${TGT_NQN}${i}
		NVMeF_NSID=${i}
		$rpc_py nvmf_subsystem_remove_listener ${NQN} -t ${TGT_TYPE} -a ${TGT_ADDR} -s ${TGT_SERVICE_ID}
		$rpc_py nvmf_subsystem_remove_ns ${NQN} ${NVMeF_NSID} # nsid 
		$rpc_py nvmf_delete_subsystem ${NQN}
	done

	for i in $(seq 1 ${DRIVE_NUM}); do

		if [ "${BDEV_TYPE}" == "mem" ]; then
			# Cleanup malloc device
			DRIVE_PREFIX="Malloc"
			echo "delete malloc bdev[$((i-1))]"
			$rpc_py bdev_malloc_delete ${DRIVE_PREFIX}$((i-1))
		elif [ "${BDEV_TYPE}" == "null" ]; then
			# cleanup null drive
			DRIVE_PREFIX="Null"
			echo "delete null bdev[$((i-1))]"
			$rpc_py bdev_null_delete ${DRIVE_PREFIX}$((i-1))
		else 
			# cleanup nvme drive
			echo "detach the nvme drive controller[$((i-1))]"
			$rpc_py bdev_nvme_detach_controller ${DRIVE_PREFIX}$((i-1))
		fi
	done

	echo "kill main process and reset environment"
	killprocess "$spdk_tgt_pid";
	${WORK_PATH}/scripts/setup.sh reset
	${WORK_PATH}/scripts/setup.sh cleanup

}


# function for exception
function handle_exception() {
	trap - ERR SIGINT SIGTERM EXIT;
	echo "Exception occurs with status $? at line[$1]"
	clean_up
	sleep infinity
}

function waitforbdev_msg() {
	local bdev_name=$1
	local i

	$rpc_py bdev_wait_for_examine
	for ((i = 1; i <= 100; i++)); do
		if $rpc_py bdev_get_bdevs | jq -r '.[] .name' | grep -qw $bdev_name; then
			return 0
		fi

		if $rpc_py bdev_get_bdevs | jq -r '.[] .aliases' | grep -qw $bdev_name; then
			return 0
		fi

		sleep 0.5
	done
	echo "create bdev ${bdev_name} false! please check your hardware"
	return 1
}

function waitforspdk() {
	if [ -z "$1" ]; then
		exit 1
	fi

	local rpc_addr="/var/tmp/spdk.sock"

	echo "Waiting for process to start up and listen on UNIX domain socket $rpc_addr..."
	# turn off trace for this loop
	local ret=0
	local i
	for ((i = 100; i != 0; i--)); do
		# if the process is no longer running, then exit the script
		#  since it means the application crashed
		if ! kill -s 0 $1; then
			echo "ERROR: process (pid: $1) is no longer running"
			ret=1
			break
		fi

		if $WORK_PATH/scripts/rpc.py -t 1 -s "$rpc_addr" rpc_get_methods &> /dev/null; then
			break
		fi

		sleep 0.5
	done

	if ((i == 0)); then
		echo "ERROR: timeout while waiting for process (pid: $1) to start listening on '$rpc_addr'"
		ret=1
	fi

	echo "The SPDK Process (pid: $1) is startup and start listening on '$rpc_addr'"

	return $ret
}



function create_nvmef_tcp() {

	OPTIONS=""
	if [ "$ENABLE_DIGEST" == "1" ]; then
		##enable digest
		OPTIONS="-e -d"
	fi

	if [ "${BDEV_TYPE}" == "mem" ]; then
		echo "create bdev over memory "
		DRIVE_PREFIX="Malloc"
		for i in $(seq 1 ${DRIVE_NUM}); do
			echo "Malloc bdev[$((i-1))]"
			${WORK_PATH}/scripts/rpc.py bdev_malloc_create 64 512 -b ${DRIVE_PREFIX}$((i-1))
		done
	elif [ "${BDEV_TYPE}" == "null" ]; then
		echo "create null bdev for test "
		DRIVE_PREFIX="Null"
		for i in $(seq 1 ${DRIVE_NUM}); do
			echo "Null bdev[$((i-1))]"
			${WORK_PATH}/scripts/rpc.py bdev_null_create ${DRIVE_PREFIX}$((i-1)) 256 512
		done
	else
		# BDEV_TYPE=="drive"
		${WORK_PATH}/build/bin/spdk_lspci  2>/dev/null
		echo "create bdev over drives "

		# Attach nvme controller with json list. drives: Nvme0 Nvme1 ...
		${WORK_PATH}/scripts/gen_nvme.sh --mode="local" -n ${DRIVE_NUM} | ${WORK_PATH}/scripts/rpc.py load_subsystem_config
		# TODO: check how many drive controllers really attached.

		# # Attach nvme controller with specific PCI device.
		# PCI_ADDR="0000:c0:00.0"
		# # attach drive and enable/disable digest.
		# ${WORK_PATH}/scripts/rpc.py bdev_nvme_attach_controller -b ${DRIVE_PREFIX} -t pcie -a ${PCI_ADDR} ${OPTIONS} 
		# # comeout the "${DRIVE_PREFIX}n1"
		# sleep 2
		# NVMeF_NS="${DRIVE_PREFIX}n1"

		#waitforbdev_msg "$NVMeF_NS"  # 20s to check whether create correctly
		${WORK_PATH}/scripts/rpc.py bdev_nvme_get_controllers
		#TODO: bind more drive as RAID for high throuput benchmark.
	fi

	# Create nvmf tcp transport:

	TP_C2H_SUCCESS_FLAG=""
	if [ "${TP_C2H_SUCCESS}" == "0" ]; then
		# Disable C2H success optimization
		TP_C2H_SUCCESS_FLAG="-o"
	fi

	TCP_TP_OPTIONS="-u ${TP_IO_UNIT_SIZE} \
					-q ${TP_MAX_QUEUE_DEPTH} \
					-m ${TP_MAX_IO_QPAIRS_PER_CTRLR} \
					-c ${TP_IN_CAPSULE_DATA_SIZE} \
					-i ${TP_MAX_IO_SIZE} \
					-n ${TP_NUM_SHARED_BUFFERS} \
					-b ${TP_BUF_CACHE_SIZE} \
					-y ${TCP_TP_SOCK_PRIORITY} \
					${TP_C2H_SUCCESS_FLAG} "

	${WORK_PATH}/scripts/rpc.py nvmf_create_transport -t ${TGT_TYPE} ${TCP_TP_OPTIONS}

	for i in $(seq 1 ${DRIVE_NUM}); do

		NQN=${TGT_NQN}${i}
		NVMeF_NSID=${i}
		${WORK_PATH}/scripts/rpc.py nvmf_create_subsystem ${NQN} -a -s ${NVMeF_SUBSYS_SN}-${i} -m ${NVMeF_MAX_NAMESPACES}

		if [ "${BDEV_TYPE}" == "drive" ]; then
			# for NVMe drive
			${WORK_PATH}/scripts/rpc.py nvmf_subsystem_add_ns -n ${NVMeF_NSID} ${NQN} ${DRIVE_PREFIX}$((i-1))n1
		else 
			${WORK_PATH}/scripts/rpc.py nvmf_subsystem_add_ns -n ${NVMeF_NSID} ${NQN} ${DRIVE_PREFIX}$((i-1))
		fi
	done



	#add listeners to NVMe-oF Subsystems:
	if [[ $DRIVE_NUM -lt $TGT_ADDR_NUM ]]; then
		echo "WARNING: No enough drive[$DRIVE_NUM] for multiple IP[$TGT_ADDR_NUM]!"

		# for single NIC use case
		echo "Bind all drive to first IP..."
		TGT_ADDR=${TGT_ADDR_ARRAY[0]}

		# check ip address exist,
		if [ "${TGT_TYPE}" == "tcp" ]; then
			if [ -z "$(ip address | grep ${TGT_ADDR})" ]; then
				echo "ERROR: No address found for ${TGT_ADDR}"
				clean_up
				exit 1
			fi
			echo "Target address[${TGT_ADDR}] is exist !"
		fi

		for i in $(seq 1 ${DRIVE_NUM}); do
			NQN=${TGT_NQN}${i}
			echo "== start the listener on ${TGT_TYPE} type targer on ${TGT_ADDR}:${TGT_SERVICE_ID}- with nqn[${NQN}] =="
			${WORK_PATH}/scripts/rpc.py nvmf_subsystem_add_listener ${NQN} -t ${TGT_TYPE} -a ${TGT_ADDR} -s ${TGT_SERVICE_ID}
		done

	else
		# For multiple IP
		i=1  # for nqn/drive index
		#IP_LIST=$TGT_ADDR_ARRAY
		#IP_list=(20.0.0.1 20.0.1.1 10.0.0.1 10.0.1.1)
		IP_INDEX=0
		for TGT_ADDR in ${TGT_ADDR_ARRAY[@]}; do

			DRIVE_MOUNT=$(($DRIVE_NUM/$TGT_ADDR_NUM))
			LEFT_DRIVE=$(($DRIVE_NUM-$DRIVE_MOUNT*$IP_INDEX))
			if [ $LEFT_DRIVE -le 0 ]; then
				echo "WARNING: No enough drive[$LEFT_DRIVE]!"
				break
			fi

			if [ $LEFT_DRIVE -le $DRIVE_MOUNT ]; then
				DRIVE_MOUNT=$LEFT_DRIVE
			fi

			# check ip address exist,
			if [ "${TGT_TYPE}" == "tcp" ]; then
				if [ -z "$(ip address | grep ${TGT_ADDR})" ]; then
					echo "ERROR: No address found for ${TGT_ADDR}"
					break
				fi
				echo "Target address[${TGT_ADDR}] is exist !"
			fi

			for j in $(seq 1 ${DRIVE_MOUNT}); do
				NQN=${TGT_NQN}${i}
				echo "== start the listener on ${TGT_TYPE} type targer on ${TGT_ADDR}:${TGT_SERVICE_ID}- with nqn[${NQN}] =="
				${WORK_PATH}/scripts/rpc.py nvmf_subsystem_add_listener ${NQN} -t ${TGT_TYPE} -a ${TGT_ADDR} -s ${TGT_SERVICE_ID}
				i=$(($i + 1))
			done

			IP_INDEX=$((IP_INDEX + 1))
		done
	fi

	echo "== Create nvme-over-tcp target successfully! =="

}

function cpu_core_mask() {
	num=$SPDK_PRO_CPUCORE
	i=1
	v=1
	xv=1
	while [ "$i" -lt "$num" ];do
			v=$(( v<<1 | 0x1 ))
			xv=`echo "ibase=10;obase=16;$v" | bc`
			i=$(($i+1))
	done

	SPDK_PRO_CPUMASK=0x${xv}
}

function spdk_specific_config {
	# enable socket zero copy .
	$rpc_py sock_impl_set_options --impl=posix --enable-zerocopy-send-server
}


function start_spdk_tgt() {

	NVMF_TGT_ARGS=""

	if [ "${SPDK_TRACE}" == "1" ]; then
		NVMF_TGT_ARGS=${NVMF_TGT_ARGS}"-e 0xFFFF"
	fi

	# for spdk tgt cpu usage.
	cpu_core_mask

	if [ "${ENABLE_DSA}" == "0" ]; then
		echo "Will not enable Intel DSA feature."
		${WORK_PATH}/build/bin/nvmf_tgt -i 0 ${NVMF_TGT_ARGS} -m ${SPDK_PRO_CPUMASK} &
		spdk_tgt_pid=$!
		waitforspdk "$spdk_tgt_pid"

		#spdk_specific_config
	else 
		# For DSA config 
		echo "Enable the Intel DSA feature for io accelerate"
		${WORK_PATH}/build/bin/nvmf_tgt -i 0 ${NVMF_TGT_ARGS}  -m ${SPDK_PRO_CPUMASK} --wait-for-rpc &
		spdk_tgt_pid=$!
		waitforspdk "$spdk_tgt_pid"
		sleep 5s
		spdk_specific_config
		# ${WORK_PATH}/scripts/rpc.py dsa_scan_accel_engine
		${WORK_PATH}/scripts/rpc.py dsa_scan_accel_module
		sleep 2s
		${WORK_PATH}/scripts/rpc.py framework_start_init
		${WORK_PATH}/scripts/rpc.py framework_wait_init
		echo "Framework init complete for DSA enable in SPDK"
	fi

}

# dump the accelerator info
function accel_info() {
	echo " == Get the accelerator module info =="
	${WORK_PATH}/scripts/rpc.py accel_get_module_info

	echo " == Get the accelerator assignments =="
	${WORK_PATH}/scripts/rpc.py accel_get_opc_assignments
}

# Dump the transport info
function transport_info {
	echo " == Get the transport[${TGT_TYPE}] info =="
	${WORK_PATH}/scripts/rpc.py nvmf_get_transports

	echo " == Get the sock info =="
	${WORK_PATH}/scripts/rpc.py sock_impl_get_options -i posix

}

if [[ $DRIVE_NUM -lt $TGT_ADDR_NUM ]]; then
	echo "WARNING: No enough drive[$DRIVE_NUM] for multiple IP[$TGT_ADDR_NUM]!"
fi

# bind nvme set huge_pages;
#export HUGE_EVEN_ALLOC="yes"
export NRHUGE=${SPDK_HUGEMEM}

${WORK_PATH}/scripts/setup.sh
trap 'handle_exception ${LINENO}' ERR SIGINT SIGTERM EXIT;

start_spdk_tgt

# start spdk creating nvme over tcp trasport
create_nvmef_tcp

accel_info

transport_info

#TODO: need to double check the tcp target is ready?

# Cleanup environment and exit
echo "Everthing is done, ready for test. "
while [ ! -f /cleanup ]; do
	sleep 5
done

trap - ERR SIGINT SIGTERM EXIT;

echo "Cleanup the environemnt and end of the test"
clean_up
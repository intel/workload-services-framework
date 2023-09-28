#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Server setting
NODE_IP=${SERVER_IP:-sm-nighthawk-server.istio-workloads.svc.cluster.local}
PORT=${SERVER_PORT:-10000}

# Common setting for both http1 & http2
MODE=${MODE:-RPS-MAX}
PROTOCOL=${PROTOCOL:-http1}
NODES=${NODES:-2n}

CLIENT_CPU=${CLIENT_CPU:-40}
CLIENT_CONNECTIONS=${CLIENT_CONNECTIONS:-1000}
CLIENT_CONCURRENCY=${CLIENT_CONCURRENCY:-40}
CLIENT_RPS=${CLIENT_RPS:-10}
CLIENT_RPS_MAX=${CLIENT_RPS_MAX:-300}
CLIENT_RPS_STEP=${CLIENT_RPS_STEP:-10}
CLIENT_RPS_MIN=${CLIENT_RPS}
CLIENT_LATENCY_BASE=${CLIENT_LATENCY_BASE:-50}

# Setting for http2
CLIENT_MAR=${CLIENT_MAR:-500}
CLIENT_MCS=${CLIENT_MCS:-100}

CRYPTO_ACC=${CRYPTO_ACC:-none}

CLIENT_MRPC=${CLIENT_MRPC:-7}
CLIENT_MPR=${CLIENT_MPR:-100}
CLIENT_RBS=${CLIENT_RBS:-400}

DURATION=${DURATION:-30}
KILL_DELAY=${KILL_DELAY:-30}

CLIENT_CPU=${CLIENT_CPU//"!"/","}

AUTO_EXTEND_INPUT=${AUTO_EXTEND_INPUT:-false}

auto_extend_rps_range() {
    # check the min input rps will blocking or not
    rps_range=$(( $CLIENT_RPS_MAX-$CLIENT_RPS_MIN ))
	CLIENT_RPS=$CLIENT_RPS_MIN
    nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
	pids=`pidof nighthawk_client`
	if [[ ${pids} != "" ]]; then
		kill -9 ${pids}
	fi
	sleep 10s
    blocking=$(cat $CLIENT_RPS.log | grep Blocking)
    while [[ "$blocking" != "" ]]; do
        # blocking! move the range lower for rps_range until to 1
        CLIENT_RPS_MAX=$CLIENT_RPS
        CLIENT_RPS=$(( $CLIENT_RPS-$rps_range ))

        if [[ $CLIENT_RPS -lt 1 ]]; then
            CLIENT_RPS=1
			blocking=""
        else
			nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
			pids=`pidof nighthawk_client`
			if [[ ${pids} != "" ]]; then
				kill -9 ${pids}
			fi
			sleep 10s
			blocking=$(cat $CLIENT_RPS.log | grep Blocking)
		fi
    done
    CLIENT_RPS_MIN=$CLIENT_RPS
	# check the max input rps will blocking
	CLIENT_RPS=$CLIENT_RPS_MAX

	nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
	pids=`pidof nighthawk_client`
	if [[ ${pids} != "" ]]; then
		kill -9 ${pids}
	fi
	sleep 10s
    blocking=$(cat $CLIENT_RPS.log | grep Blocking)
	while [[ "$blocking" == "" ]]; do
		while [[ "$blocking" == "" ]]; do
			# non-blocking
			CLIENT_RPS_MIN=$CLIENT_RPS
			CLIENT_RPS=$(( $CLIENT_RPS+$rps_range ))
			nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
			pids=`pidof nighthawk_client`
			if [[ ${pids} != "" ]]; then
				kill -9 ${pids}
			fi
			sleep 10s
			blocking=$(cat $CLIENT_RPS.log | grep Blocking)
		done
		# Blocking! check again
		nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
		pids=`pidof nighthawk_client`
		if [[ ${pids} != "" ]]; then
			kill -9 ${pids}
		fi
		sleep 10s
	blocking=$(cat $CLIENT_RPS.log | grep Blocking)
	done
	CLIENT_RPS_MAX=$CLIENT_RPS
	# if [[ ${CLIENT_RPS_MIN} > ${rps_range} ]]; then
	# 	CLIENT_RPS_MIN=$(( $CLIENT_RPS_MIN-$rps_range ))
	# fi
}

auto_extend_sla_range() {
	sla_gt=1
	# check the min input rps sla
    rps_range=$(( $CLIENT_RPS_MAX-$CLIENT_RPS_MIN ))
	CLIENT_RPS=$CLIENT_RPS_MIN
	retry=0
	while [[ sla_gt -eq 1 ]]; do
		nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
		pids=`pidof nighthawk_client`
		if [[ ${pids} != "" ]]; then
			kill -9 ${pids}
		fi
		sleep 10s
		s=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $3}' | awk -F 's' '{print $1}')
		ms=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $4}' | awk -F 'ms' '{print $1}')
		us=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $5}' | awk -F 'us' '{print $1}')
		P99=$(echo "scale=3;$s * 1000 + $ms + $us / 1000" | bc)

		if [[ `echo "$P99 > $CLIENT_LATENCY_BASE" | bc` -eq 1 ]]; then
			printf "Latency P99: %sms > %sms!!\n" "$P99" "$CLIENT_LATENCY_BASE"
			if [[ retry -lt 3 ]]; then
				retry=$(( $retry+1 ))
				echo "retry 1: $retry"
			else
				CLIENT_RPS_MAX=$CLIENT_RPS
				CLIENT_RPS=$(( $CLIENT_RPS-$rps_range ))
				if [[ $CLIENT_RPS -lt 1 ]]; then
					CLIENT_RPS_MIN=1
					sla_gt=0
				fi
			fi
		else
			CLIENT_RPS_MIN=$CLIENT_RPS
			sla_gt=0
		fi
	done
	# check the max input rps sla
	sla_lt=1
	CLIENT_RPS=$CLIENT_RPS_MAX
	retry=0
	while [[ sla_lt -eq 1 ]]; do
		nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
		pids=`pidof nighthawk_client`
		if [[ ${pids} != "" ]]; then
			kill -9 ${pids}
		fi
		sleep 10s
		s=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $3}' | awk -F 's' '{print $1}')
		ms=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $4}' | awk -F 'ms' '{print $1}')
		us=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $5}' | awk -F 'us' '{print $1}')
		P99=$(echo "scale=3;$s * 1000 + $ms + $us / 1000" | bc)

		if [[ `echo "$P99 > $CLIENT_LATENCY_BASE" | bc` -eq 1 ]]; then
			printf "Latency P99: %sms > %sms!!\n" "$P99" "$CLIENT_LATENCY_BASE"
			CLIENT_RPS_MAX=$CLIENT_RPS
			sla_lt=0
		else
			if [[ retry -lt 3 ]]; then
				retry=$(( $retry+1 ))
				echo "retry 2: $retry"
			else
				CLIENT_RPS=$(( $CLIENT_RPS+$rps_range ))
			fi
		fi
	done
}

nighthawk_test() {
	if (( $# != 1 )); then
		echo "Incorrect number of parameters sent to nighthawk_test function."
		exit 1
	elif ! [[ "$1" =~ ^[0-9]+$ ]]; then
		echo "Incorrectly stated duration of measurement."
		exit 1
	fi

	echo
	echo "Start of Nighthawk measurement..."
	echo "Some information about measurement:"
	echo "	- Server IP: $NODE_IP"
	echo "	- Port: $PORT"
	echo "	- RPS: $CLIENT_RPS"
	echo "	- Duration: $1 sec"

	if [[ "$PROTOCOL" == "http1" ]]; then
		echo "	- Protocol: HTTP/1.1"
		echo
		echo "taskset -c "$CLIENT_CPU" nighthawk_client -p "$PROTOCOL" --connections "$CLIENT_CONNECTIONS" --request-body-size 400 --concurrency "$CLIENT_CONCURRENCY" --rps "$CLIENT_RPS"  --duration "$1" "$NODE_IP":"$PORT" > "$CLIENT_RPS".log"
		taskset -c "$CLIENT_CPU" nighthawk_client -p "$PROTOCOL" --connections "$CLIENT_CONNECTIONS" --request-body-size 400 --concurrency "$CLIENT_CONCURRENCY" --rps "$CLIENT_RPS"  --duration "$1" "$NODE_IP":"$PORT" > "$CLIENT_RPS".log
		stat=$?
		if (( stat != 0 )) && (( stat != 137 )); then #While the script is running, it may be the case that the Nighthawk process is specifically killed. The skip code 137 is there to avoid displaying an error message in this case
			echo
			echo "Something has gone wrong. Are you sure Nighthawk and taskset are installed?"
			echo "It is also possible that you have specified the range of threads to be used by taskset, in an incorrect format."
			echo "Possible formats:"
			echo "	- single thread, e.g. 1"
			echo "	- threads listed after a comma, e.g. 1,2,3"
			echo "	- range of threads, e.g. 1-5"
			echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
			echo "Do not use spaces."
			#kill 0
		fi
	elif [[ "$PROTOCOL" == "http2" ]]; then
		echo "	- Protocol: HTTP/2"
		echo
		echo "taskset -c "$CLIENT_CPU" nighthawk_client -p "$PROTOCOL" --max-concurrent-streams "$CLIENT_MCS" --max-active-requests "$CLIENT_MAR" --request-body-size 400 --concurrency "$CLIENT_CONCURRENCY" --rps "$CLIENT_RPS"  --duration "$1" "$NODE_IP":"$PORT" > "$CLIENT_RPS".log"
		taskset -c "$CLIENT_CPU" nighthawk_client -p "$PROTOCOL" --max-concurrent-streams "$CLIENT_MCS" --max-active-requests "$CLIENT_MAR" --request-body-size 400 --concurrency "$CLIENT_CONCURRENCY" --rps "$CLIENT_RPS"  --duration "$1" "$NODE_IP":"$PORT" > "$CLIENT_RPS".log
		stat=$?
		if (( stat != 0 )) && (( stat != 137 )); then #While the script is running, it may be the case that the Nighthawk process is specifically killed. The skip code 137 is there to avoid displaying an error message in this case
			echo
			echo "Something has gone wrong. Are you sure Nighthawk and taskset are installed?"
			echo "It is also possible that you have specified the range of threads to be used by taskset, in an incorrect format."
			echo "Possible formats:"
			echo "	- single thread, e.g. 1"
			echo "	- threads listed after a comma, e.g. 1,2,3"
			echo "	- range of threads, e.g. 1-5"
			echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
			echo "Do not use spaces."
			#kill 0
		fi
	elif [[ "$PROTOCOL" == "https" ]]; then
		echo "	- Protocol: HTTPS"
		echo
		echo "taskset -c "$CLIENT_CPU" nighthawk_client --max-requests-per-connection "$CLIENT_MRPC" --max-pending-requests "$CLIENT_MPR" --max-active-requests "$CLIENT_MAR" --max-concurrent-streams "$CLIENT_MCS" --address-family v4 "https://$NODE_IP":"$PORT" -p http2 --concurrency "$CLIENT_CONCURRENCY" --rps "$CLIENT_RPS"  --duration "$1" --request-body-size "$CLIENT_RBS" --transport-socket '{"name": "envoy.transport_sockets.tls", "typed_config": { "@type":"type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext","max_session_keys":"0"}}' > "$CLIENT_RPS".log"
		taskset -c "$CLIENT_CPU" nighthawk_client --max-requests-per-connection "$CLIENT_MRPC" --max-pending-requests "$CLIENT_MPR" --max-active-requests "$CLIENT_MAR" --max-concurrent-streams "$CLIENT_MCS" --address-family v4 "https://$NODE_IP":"$PORT" -p http2 --concurrency "$CLIENT_CONCURRENCY" --rps "$CLIENT_RPS"  --duration "$1" --request-body-size "$CLIENT_RBS" --transport-socket '{"name": "envoy.transport_sockets.tls", "typed_config": { "@type":"type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext","max_session_keys":"0"}}' > "$CLIENT_RPS".log
		stat=$?
		if (( stat != 0 )) && (( stat != 137 )); then #While the script is running, it may be the case that the Nighthawk process is specifically killed. The skip code 137 is there to avoid displaying an error message in this case
			echo
			echo "Something has gone wrong. Are you sure Nighthawk and taskset are installed?"
			echo "It is also possible that you have specified the range of threads to be used by taskset, in an incorrect format."
			echo "Possible formats:"
			echo "	- single thread, e.g. 1"
			echo "	- threads listed after a comma, e.g. 1,2,3"
			echo "	- range of threads, e.g. 1-5"
			echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
			echo "Do not use spaces."
			#kill 0
		fi
	else
		echo "Error: Wrong Protocol type ${PROTOCOL}"
	fi
}

get_max_rps() {
	CLIENT_RPS=$TEMP
	COMPARE_RPS_MAX=0
	COMPARE_RPS_LOC=0

	for ((CLIENT_RPS; CLIENT_RPS<=CLIENT_RPS_MAX; CLIENT_RPS=CLIENT_RPS+CLIENT_RPS_STEP)); do
		blocking=$(cat $CLIENT_RPS.log | grep Blocking)
		achieved_RPS=$(cat $CLIENT_RPS.log | grep benchmark.http_2xx | awk '{print $3}')
		P90=$(cat $CLIENT_RPS.log | grep ' 0\.9 ' | tail -n1 | xargs | cut -d ' ' -f3-)
		P99=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | cut -d ' ' -f3-)
		P999=$(cat $CLIENT_RPS.log | grep ' 0\.9990' | tail -n1 | xargs | cut -d ' ' -f3-)
		if [[ "$blocking" != "" ]]; then
			printf "Input RPS:%s\t Achived_RPS:%s\t Latency9:%s\t Latency99:%s\t Latency999:%s\t|\t MAX_achived:%s\t MAX_input:%s" "$CLIENT_RPS" "$achieved_RPS" "$P90" "$P99" "$P999" "$COMPARE_RPS_MAX" "$COMPARE_RPS_LOC"
			printf "\t|\t BLOCKING!!\n" "$CLIENT_RPS"
		else
			if [[ `echo "$achieved_RPS > $COMPARE_RPS_MAX" | bc` -eq 1 ]]; then
				COMPARE_RPS_MAX=$achieved_RPS
				COMPARE_RPS_LOC=$CLIENT_RPS
			fi
			printf "Input RPS:%s\t Achived_RPS:%s\t Latency9:%s\t Latency99:%s\t Latency999:%s\t|\t MAX_achived:%s\t MAX_input:%s\n" "$CLIENT_RPS" "$achieved_RPS" "$P90" "$P99" "$P999" "$COMPARE_RPS_MAX" "$COMPARE_RPS_LOC"
		fi
	done
	printf "The Max achieved RPS is: %s, the input RPS is %s.\n" "$COMPARE_RPS_MAX" "$COMPARE_RPS_LOC"
	cp $COMPARE_RPS_LOC.log performance.log
}

get_RPS-SLA() {
	CLIENT_RPS=$TEMP
	COMPARE_P99_MAX=0
	COMPARE_P99_LOC=0
	for ((CLIENT_RPS; CLIENT_RPS<=CLIENT_RPS_MAX; CLIENT_RPS=CLIENT_RPS+CLIENT_RPS_STEP)); do
		s=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $3}' | awk -F 's' '{print $1}')
		ms=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $4}' | awk -F 'ms' '{print $1}')
		us=$(cat $CLIENT_RPS.log | grep ' 0\.990' | tail -n1 | xargs | awk '{print $5}' | awk -F 'us' '{print $1}')
		P99=$(echo "scale=3;$s * 1000 + $ms + $us / 1000" | bc)
		if [[ `echo "$P99 > $CLIENT_LATENCY_BASE" | bc` -eq 1 ]]; then
			printf "Latency P99: %sms > %sms!!\n" "$P99" "$CLIENT_LATENCY_BASE"
		else
			achieved_RPS=$(cat $CLIENT_RPS.log | grep benchmark.http_2xx | awk '{print $3}')
			if [[ `echo "$achieved_RPS > $COMPARE_P99_MAX" | bc` -eq 1 ]]; then
				COMPARE_P99_MAX=$achieved_RPS
				COMPARE_P99_LOC=$CLIENT_RPS 
			fi
			printf "Input RPS:%s\t Achived_RPS:%s\t Latency99:%s\t RPS-SLA_achived:%s\t RPS-SLA_input:%s\n" "$CLIENT_RPS" "$achieved_RPS" "$P99" "$COMPARE_P99_MAX" "$COMPARE_P99_LOC"
		fi
	done
	printf "The RPS-SLA is: %s, the input RPS is %s.\n" "$COMPARE_P99_MAX" "$COMPARE_P99_LOC"
	cp $COMPARE_P99_LOC.log performance.log
}

TEMP=$CLIENT_RPS

CLIENT_CPU=${CLIENT_CPU//"!"/","}
echo "CLIENT_CPU: $CLIENT_CPU"

echo "start of region"
nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
pids=`pidof nighthawk_client`
if [[ ${pids} != "" ]]; then
	kill -9 ${pids}
fi
sleep 10s

if [[ $AUTO_EXTEND_INPUT == "true" ]]; then
	if [[ $MODE == "RPS-MAX" ]]; then
		auto_extend_rps_range
	elif [[ $MODE == "RPS-SLA" ]]; then
		auto_extend_rps_range
		auto_extend_sla_range
	else
		echo "Something has gone wrong. Please choose mode as RPS-MAX or RPS-SLA."
	fi
fi

CLIENT_RPS=$CLIENT_RPS_MIN

nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
pids=`pidof nighthawk_client`
if [[ ${pids} != "" ]]; then
	kill -9 ${pids}
fi
sleep 10s
blocking=$(cat $CLIENT_RPS.log | grep Blocking)

if [[ "$blocking" != "" && $MODE == "RPS-MAX" && $AUTO_EXTEND_INPUT == "true" ]];then
	while [[ "$blocking" != "" ]]; do
		CLIENT_RPS=$(( $CLIENT_RPS-$CLIENT_RPS_STEP ))
		if [[ $CLIENT_RPS -lt 1 ]];then
			$CLIENT_RPS=1
		fi
		nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
		pids=`pidof nighthawk_client`
		if [[ ${pids} != "" ]]; then
			kill -9 ${pids}
		fi
		sleep 10s
		blocking=$(cat $CLIENT_RPS.log | grep Blocking)
	done
	CLIENT_RPS_MIN=$CLIENT_RPS
	CLIENT_RPS_MAX=$CLIENT_RPS
else
	for ((CLIENT_RPS; CLIENT_RPS<=CLIENT_RPS_MAX; CLIENT_RPS=CLIENT_RPS+CLIENT_RPS_STEP)); do
		nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
		pids=`pidof nighthawk_client`
		if [[ ${pids} != "" ]]; then
			kill -9 ${pids}
		fi
		sleep 10s
	done
	if [[ $MODE == "RPS-MAX" && $AUTO_EXTEND_INPUT == "true" ]]; then
		blocking=$(cat $CLIENT_RPS.log | grep Blocking)
		if [[ "$blocking" == "" ]];then
			while [[ "$blocking" == "" ]]; do
				while [[ "$blocking" == "" ]]; do
					# non-blocking
					# CLIENT_RPS_MIN=$CLIENT_RPS
					CLIENT_RPS=$(( $CLIENT_RPS+$CLIENT_RPS_STEP ))
					nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
					pids=`pidof nighthawk_client`
					if [[ ${pids} != "" ]]; then
						kill -9 ${pids}
					fi
					sleep 10s
					blocking=$(cat $CLIENT_RPS.log | grep Blocking)
				done
				# Blocking! check again
				nighthawk_test "$DURATION" & sleep $(( $DURATION + $KILL_DELAY));
				pids=`pidof nighthawk_client`
				if [[ ${pids} != "" ]]; then
					kill -9 ${pids}
				fi
				sleep 10s
				blocking=$(cat $CLIENT_RPS.log | grep Blocking)
			done
			CLIENT_RPS_MAX=$CLIENT_RPS
		fi
	fi
fi
echo "end of region"

TEMP=$CLIENT_RPS_MIN
if [[ $MODE == "RPS-MAX" ]]; then
	get_max_rps
elif [[ $MODE == "RPS-SLA" ]]; then
	get_RPS-SLA
else
	echo "Something has gone wrong. Please choose mode as RPS-MAX or RPS-SLA."
fi

echo "All done! Measurements completed :)"
exit 0

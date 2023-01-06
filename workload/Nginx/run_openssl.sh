#!/bin/bash

#this openssl s_time https connection testing client/method copy from:
#
#https://github.com/intel-innersource/frameworks.benchmarking.cumulus.perfkitbenchmarker/blob/main/perfkitbenchmarker/data/nginx_with_qat/connection.sh.j2
#
#https://github.com/intel-innersource/frameworks.benchmarking.cumulus.perfkitbenchmarker/tree/main/perfkitbenchmarker/data/nginx_with_qat
#
#https://github.com/intel-innersource/frameworks.benchmarking.cumulus.perfkitbenchmarker/blob/main/perfkitbenchmarker/linux_benchmarks/nginx_with_qat_benchmark.py

NODE=${NODE:-2}
MODE=${MODE:-https}
NGINX_HOST=${NGINX_SERVICE_NAME:-nginx-server-service}
PORT=${PORT:-443}
NGINX_WORKERS=${NGINX_WORKERS:-4}

default_clients_num=$(( $NGINX_WORKERS * 50 + 100 ))
if [ $NGINX_WORKERS -eq 1 ]; then
  default_clients_num=100
fi

lscpu;
echo docker available nproc number `nproc`

if [ -z "$(lscpu | grep Hypervisor)" ]; then
  echo test in local bare metal
else
  echo test in cloud VM
  default_clients_num=2000
fi

clients=${OPENSSL_CLIENTS:-$default_clients_num}
_time=${TEST_TIME:-60}
cipher=${CIPHER:-AES128-GCM-SHA256}

# client wait nginx server ready
wget_cur_wait_loop=0
while [ ! $NGINX_RESPONSE ] || [ $NGINX_RESPONSE -ne 200 ] ; 
do
  wget_cur_wait_loop=$(( $wget_cur_wait_loop + 1 ))

  if (( wget_cur_wait_loop > 100 )); then
    echo client wait for Nginx server $MODE://$NGINX_HOST:$PORT timeout;
    exit 3;
  fi

  echo round:$wget_cur_wait_loop wget_waiting $MODE://$NGINX_HOST:$PORT...;sleep 3s; 
  NGINX_RESPONSE=$(wget --server-response --no-check-certificate $MODE://$NGINX_HOST:$PORT 2>&1 | awk '/^  HTTP/{print $2}')
done
echo wget waiting $MODE://$NGINX_HOST:$PORT available done

# try to get Nginx server IP address to stress, Nginx service name perf is much lower
timeout -s 9 20s wget --no-check-certificate $MODE://$NGINX_HOST:$PORT/nginxservernodeip
timeout -s 9 20s wget --no-check-certificate $MODE://$NGINX_HOST:$PORT/nginxserverpodip

if [ -s "nginxservernodeip" ]; then
  echo nginxservernodeip file size is not zero
  NGINX_SERVER_NODE_IP=$(cat nginxservernodeip)
  rm -f nginxservernodeip
  echo NGINX_SERVER_NODE_IP:$NGINX_SERVER_NODE_IP
  timeout -s 9 20s wget --no-check-certificate $MODE://$NGINX_SERVER_NODE_IP:$PORT/nginxservernodeip
  if [ -s "nginxservernodeip" ]; then
    NGINX_SERVER_NODE_IP_2=$(cat nginxservernodeip)
    echo NGINX_SERVER_NODE_IP_2:$NGINX_SERVER_NODE_IP_2
    if [ $NGINX_SERVER_NODE_IP == $NGINX_SERVER_NODE_IP_2 ]; then
      echo confirmed this IP $NGINX_SERVER_NODE_IP for nginx server 
      NGINX_HOST=$NGINX_SERVER_NODE_IP
      echo NGINX_HOST:$NGINX_HOST
    fi
  fi
else
  if [ -s "nginxserverpodip" ]; then
    echo nginxserverpodip file size is not zero
    NGINX_SERVER_POD_IP=$(cat nginxserverpodip)
    rm -f nginxserverpodip
    echo NGINX_SERVER_POD_IP:$NGINX_SERVER_POD_IP
    timeout -s 9 20s wget --no-check-certificate $MODE://$NGINX_SERVER_POD_IP:$PORT/nginxserverpodip
    if [ -s "nginxserverpodip" ]; then
      NGINX_SERVER_POD_IP2=$(cat nginxserverpodip)
      if [ $NGINX_SERVER_POD_IP == $NGINX_SERVER_POD_IP2 ]; then
         echo confirmed this IP $NGINX_SERVER_POD_IP for nginx server
         NGINX_HOST=$NGINX_SERVER_POD_IP
         echo NGINX_HOST:$NGINX_HOST
      fi
    fi
  fi
fi

#cmd1 is the first part of the commandline and cmd2 is the second partrt
#The total commandline will be cmd1 + "192.168.1.1:4400" + cmd2
cmd1="openssl s_time -connect"
if [[ $cipher =~ "TLS" ]];   # CIPHER is *TLS*
then
        cmd2="-new -ciphersuites $cipher  -time $_time "
else
        cmd2="-new -cipher $cipher  -time $_time "
fi
#Print out variables to check
printf " Nginx Host:                    $NGINX_HOST\n"
printf " Test Time:                     $_time\n"
printf " Clients:                       $clients\n"
printf " Port:                          $PORT\n"
printf " Cipher:                        $cipher\n\n"


# ufw disable

# we may need this ACCEPT before iptables -F for local static, with iptable rules
# iptables -P INPUT ACCEPT
# iptables -F

# ulimit -a
#ulimit -v unlimited
#ulimit -m unlimited
#ulimit -l unlimited
#ulimit -n unlimited
#ulimit -i unlimited   # those three cannot exec in docker non-privileged mode
#ulimit -s unlimited
#ulimit -u unlimited

#TCP Memory
# echo 16777216                > /proc/sys/net/core/rmem_max
# echo 16777216                > /proc/sys/net/core/wmem_max
# echo 16777216                > /proc/sys/net/core/rmem_default
# echo 16777216                > /proc/sys/net/core/wmem_default
# echo 16777216 16777216 16777216  > /proc/sys/net/ipv4/tcp_rmem
# echo 538750 538750 538750  > /proc/sys/net/ipv4/tcp_wmem
# echo 16777216                    > /proc/sys/net/core/optmem_max
# echo 16777216 16777216  16777216 > /proc/sys/net/ipv4/tcp_mem
# echo 65536               > /proc/sys/vm/min_free_kbytes
#TCP Behavior
# echo 0                     > /proc/sys/net/ipv4/tcp_timestamps
# echo 0                     > /proc/sys/net/ipv4/tcp_sack
# echo 0                     > /proc/sys/net/ipv4/tcp_fack
# echo 0                     > /proc/sys/net/ipv4/tcp_dsack
# echo 0                     > /proc/sys/net/ipv4/tcp_moderate_rcvbuf
# echo 1                     > /proc/sys/net/ipv4/tcp_rfc1337
# echo 600        > /proc/sys/net/core/netdev_budget
# echo 128                   > /proc/sys/net/core/dev_weight
# echo 1                     > /proc/sys/net/ipv4/tcp_syncookies
# echo 0                     > /proc/sys/net/ipv4/tcp_slow_start_after_idle
# echo 1                     > /proc/sys/net/ipv4/tcp_no_metrics_save
# echo 1                     > /proc/sys/net/ipv4/tcp_orphan_retries
# echo 0                     > /proc/sys/net/ipv4/tcp_fin_timeout
# echo 0                     > /proc/sys/net/ipv4/tcp_tw_reuse
# echo 1                     > /proc/sys/net/ipv4/tcp_syncookies
# echo 2                           > /proc/sys/net/ipv4/tcp_synack_retries
# echo 2                     > /proc/sys/net/ipv4/tcp_syn_retries
# echo cubic                   > /proc/sys/net/ipv4/tcp_congestion_control
# echo 1                     > /proc/sys/net/ipv4/tcp_low_latency
# echo 1                     > /proc/sys/net/ipv4/tcp_window_scaling
# echo 1                     > /proc/sys/net/ipv4/tcp_adv_win_scale
# #TCP Queueing
# echo 0                > /proc/sys/net/ipv4/tcp_max_tw_buckets
# echo 1025 65535            > /proc/sys/net/ipv4/ip_local_port_range
# echo 131072                > /proc/sys/net/core/somaxconn
# echo 262144            > /proc/sys/net/ipv4/tcp_max_orphans
# echo 262144           > /proc/sys/net/core/netdev_max_backlog
# echo 262144        > /proc/sys/net/ipv4/tcp_max_syn_backlog
# echo 4000000             > /proc/sys/fs/nr_open

# echo 4194304     > /proc/sys/net/ipv4/ipfrag_high_thresh
# echo 3145728     > /proc/sys/net/ipv4/ipfrag_low_thresh
# echo 30          > /proc/sys/net/ipv4/ipfrag_time
# echo 0   > /proc/sys/net/ipv4/tcp_abort_on_overflow
# echo 1           > /proc/sys/net/ipv4/tcp_autocorking
# echo 31          > /proc/sys/net/ipv4/tcp_app_win
# echo 0           > /proc/sys/net/ipv4/tcp_mtu_probing
# set selinux=disabled
# ulimit -n 1000000

echo $clients X openssl s_time -connect $NGINX_HOST:$(($PORT)) $cmd2 

for test_round in {1..90}; do

  rm -rf ./.test_*

  # diff node here!
  if [ $NODE == 1 ]; then
    remain_cores=$(( `nproc` - $NGINX_WORKERS))
    sleep 0;
    starttime=$(date +%s)
    for (( i = 0; i < ${clients}; i++ )); do
      taskset -c $(( $(( $i % $remain_cores )) + $NGINX_WORKERS )) openssl s_time -connect $NGINX_HOST:$(($PORT)) $cmd2 > .test_$(($PORT))_$i &
#     openssl s_time -connect $NGINX_HOST:$(($PORT)) $cmd2 > .test_$(($PORT))_$i &
    done
    waitstarttime=$(date +%s)
  else
    if [ -z "$(lscpu | grep Hypervisor)" ]; then
      sleep 0;
      starttime=$(date +%s)
      for (( i = 0; i < ${clients}; i++ )); do
        openssl s_time -connect $NGINX_HOST:$(($PORT)) $cmd2 > .test_$(($PORT))_$i &
      done
      waitstarttime=$(date +%s)
    else
      sleep 0;
      starttime=$(date +%s)
      for (( i = 0; i < ${clients}; i++ )); do
        nice -n -20 openssl s_time -connect $NGINX_HOST:$(($PORT)) $cmd2 > .test_$(($PORT))_$i &
      done
      waitstarttime=$(date +%s)
    fi
  fi

  if { [ $NGINX_WORKERS -gt 16 ] && [ $(($waitstarttime - $starttime)) -gt 13 ]; } || \
     { [ $NGINX_WORKERS -ge 8 ] && [ $(($waitstarttime - $starttime)) -gt 100 ]; } || \
	 { [ $NGINX_WORKERS -ge 4 ] && [ $(($waitstarttime - $starttime)) -gt 150 ]; }
  then
    echo round $test_round testing launch time $(($waitstarttime - $starttime))s too long. vcpu:`nproc`
    while [ $(ps -ef | grep "openssl s_time" | wc -l) != 1 ];
    do
      killall -q openssl
      sleep 5
      killall -s 9 -q openssl
      sleep 5
    done
  else
    break
  fi

done

# wait until all processes complete
while [ $(ps -ef | grep "openssl s_time" | wc -l) != 1 ];
do
    sleep 1
done

total=$(cat ./.test_$(($PORT))* | awk '(/^[0-9]* connections in [0-9]* real/){ total += $1/$4 } END {print total}')
echo $total >> .test_sum
sumTotal=$(cat .test_sum | awk '{total += $1 } END { print total }')

printf "HTTPS($cipher)_Nginx_core_number:  $NGINX_WORKERS\n"
printf "OpenSSL_test_client_number:  $clients\n"
printf "Seconds_to_start_clients:    %d\n" $(($waitstarttime - $starttime))
printf "OpenSSL_s_time_test_period:  $_time\n"
printf "Connections_per_second:      $sumTotal\n"

rm -f ./.test_*

printf "Test_case_cost_seconds:      %d\n" $(($(date +%s) - $starttime)) 

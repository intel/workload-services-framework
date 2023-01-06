#!/bin/bash

NODE=${NODE:-2}
MODE=${MODE:-https}
NGINX_HOST=${NGINX_SERVICE_NAME:-nginx-server-service}
PORT=${PORT:-443}
APACHE_PATH=${APACHE_PATH:-"/home"}
APACHE_BINARY=ab
GETFILE=${GETFILE:-index.html}
CLIENT_CPU_LISTS=${CLIENT_CPU_LISTS:-0} 

echo "client testing configurations:"
echo NODE:$NODE
echo MODE:$MODE
echo NGINX_HOST:$NGINX_HOST
echo PORT:$PORT
echo CLIENT_ID:$CLIENT_ID
echo GETFILE:$GETFILE
echo CLIENT_CPU_LISTS:$CLIENT_CPU_LISTS

PROTOCOL=${PROTOCOL:-TLSv1.3}
CIPHER=${CIPHER:-AES128-GCM-SHA256}
CURVE=${CURVE:-secp384r1}
CERT=${CERT:-rsa2048}

# correct the format of input PROTOCOL
PROTOCOL=$(echo "$PROTOCOL" | sed 's/v//g')

echo PROTOCOL:$PROTOCOL
echo CIPHER:$CIPHER
echo CURVE:$CURVE
echo CERT:$CERT

if [[ $MODE == "http" ]]; then
  REQUESTS=${REQUESTS:-1000000}
  CONCURRENCY=${CONCURRENCY:-300}
else
  REQUESTS=${REQUESTS:-100000}
  CONCURRENCY=${CONCURRENCY:-100}
fi

echo REQUESTS:$REQUESTS
echo CONCURRENCY:$CONCURRENCY

# client wait nginx server ready
wget_cur_wait_loop=0
NGINX_RESPONSE=0
while [ ! $NGINX_RESPONSE ] || [ $NGINX_RESPONSE -ne 200 ] ; 
do
  wget_cur_wait_loop=$(( $wget_cur_wait_loop + 1 ))
  if (( wget_cur_wait_loop > 200 )); then
    echo client wait for Nginx server $MODE://$NGINX_HOST:$PORT timeout;
    exit 3;
  fi
  echo round:$wget_cur_wait_loop wget_waiting $MODE://$NGINX_HOST:$PORT...;sleep 3s; 
  NGINX_RESPONSE=$(wget --server-response --no-check-certificate $MODE://$NGINX_HOST:$PORT 2>&1 | awk '/^  HTTP/{print $2}')
  echo NGINX_RESPONSE:$NGINX_RESPONSE
done
echo wget waiting $MODE://$NGINX_HOST:$PORT available done

# try to get Nginx server IP address to stress, Nginx dns service_name perf is much lower than IP;
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

if [ $PORT ]; then
    URL=$MODE://$NGINX_HOST:$PORT/$GETFILE
else
    URL=$MODE://$NGINX_HOST/$GETFILE
fi

echo Client stress URL:$URL

NGINX_WORKERS=${NGINX_WORKERS:-4}
CLIENT_CPU_NUM=${CLIENT_CPU_NUM:-$NGINX_WORKERS}
echo NGINX_WORKERS:$NGINX_WORKERS
echo CLIENT_CPU_NUM:$CLIENT_CPU_NUM

whole_system_cores=`nproc`
system_last_core_id=`expr $whole_system_cores - 1`
echo system cores $whole_system_cores, core list 0 - $system_last_core_id

begin=0
if [ $NODE == 1 ]; then
  begin=$NGINX_WORKERS
fi

# for 2node simu 3node only
#if [ $CLIENT_ID == 2 ]; then
#  begin=$CLIENT_CPU_NUM
#fi

end=`expr $begin + $CLIENT_CPU_NUM - 1`

echo client testing cpu cores begin at $begin

if [ $begin -gt $system_last_core_id ]; then
  echo Error, no cores for client running, nginx used cores: $NGINX_WORKERS
  exit 3;
fi

if [ $end -gt $system_last_core_id ]; then
  echo Error/Warning, client worker node has no enough lcores for apache bench clients running
  echo client requested $CLIENT_CPU_NUM cores as list: $begin - $end , actually system free cores list for clients: $begin - $system_last_core_id
   exit 3;
   # or we can ignore not enough cpu cores for client?
   # end=$system_last_core_id
fi

CLIENT_TESTING_REAL_NUM=$(( $end - $begin + 1 ))
echo client testing cpu core number $CLIENT_TESTING_REAL_NUM, core list: $begin-$end

#ulimit -v unlimited
#ulimit -m unlimited
#ulimit -l unlimited
#ulimit -n unlimited
#ulimit -i unlimited   # those three cannot exec in docker non-privileged mode
#ulimit -s unlimited
#ulimit -u unlimited

# ufw disable

# we may need this ACCEPT before iptables -F for local static, with iptable rules
# iptables -P INPUT ACCEPT
# iptables -F

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
#TCP Queueing
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

# echo 262144 > /proc/sys/net/core/somaxconn
# echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

ulimit -a
lscpu

# client check nginx server IP address access ready
wget_cur_wait_loop=0
NGINX_RESPONSE=0
while [ ! $NGINX_RESPONSE ] || [ $NGINX_RESPONSE -ne 200 ] ; 
do
  wget_cur_wait_loop=`expr $wget_cur_wait_loop + 1`
  if (( wget_cur_wait_loop > 100 )); then
    echo client wait for Nginx server $URL timeout;
    exit 3;
  fi
  echo round:$wget_cur_wait_loop wget_waiting $URL...;sleep 3s; 
  NGINX_RESPONSE=$(wget --server-response --no-check-certificate $URL 2>&1 | awk '/^  HTTP/{print $2}')
  echo NGINX_RESPONSE:$NGINX_RESPONSE
done
echo wget waiting $URL available done

echo This client will launch `expr $end - $begin + 1` cmd lines for client stress:
if [ $CLIENT_CPU_LISTS != 0 ]; then
  CLIENT_CPU_LISTS_ARRAY=()
  array=(`echo $CLIENT_CPU_LISTS | tr ',' ' '`)
  for var in ${array[@]}
    do echo $var
    if [[ $var == *-* ]]; then 
      tmp=(`echo $var | tr '-' ' '`)
      for (( i=${tmp[0]};i<=${tmp[1]};i=i+1 )); do
        l=${#CLIENT_CPU_LISTS_ARRAY[*]}
        CLIENT_CPU_LISTS_ARRAY[$l]=$i 
      done
    else 
      l=${#CLIENT_CPU_LISTS_ARRAY[*]}
      CLIENT_CPU_LISTS_ARRAY[$l]=$var 
    fi
  done
  echo CLIENT_CPU_LISTS_ARRAY:${CLIENT_CPU_LISTS_ARRAY[*]} 
fi

if [ $CLIENT_CPU_LISTS != 0 ]; then
  for i in ${CLIENT_CPU_LISTS_ARRAY[*]}; do
    if [ $GETFILE != index.html ]; then
      echo taskset -c ${i} ab -n $REQUESTS -q -r -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL
    else
      echo taskset -c ${i} ab -n $REQUESTS -q -r -i -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL
    fi
  done
else
  for (( i=$begin;i<=$end;i=i+1 )); do
    if [ $GETFILE != index.html ]; then
      echo taskset -c ${i} ab -n $REQUESTS -q -r -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL
    else
      echo taskset -c ${i} ab -n $REQUESTS -q -r -i -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL
    fi
  done
fi

if [ $CLIENT_ID == 2 ]; then
  sed -i "s|listen 80|listen 999|" /usr/local/share/nginx/conf/nginx-http-with-upload.conf
  nginx -c /usr/local/share/nginx/conf/nginx-http-with-upload.conf
fi

for i in {1..90}; do

# clean up
rm -f tmp*.log
rm -f client?_cps_ok.txt
rm -f client?_ready.txt

# client1 & client2 sync to start the stress
if [ $NODE == 3 ]; then
 if [ $CLIENT_ID == 2 ]; then
  echo ready > /var/www/html/client2_ready.txt   # self ready marker
  echo client node 2 wait for client node 1 ready
  while [ ! -s /var/www/html/client1_ready.txt ]; do
    sleep 0;
  done
  rm -f /var/www/html/client?_ready.txt
  rm -f /var/www/html/client?_cps_ok.txt
  echo go
 else
  # client1 wait client2 ready
  wget_client2_wait_loop=0
  while [ ! -f client2_ready.txt ] ; 
  do
    wget_client2_wait_loop=$(( $wget_client2_wait_loop + 1 ))
    if (( wget_client2_wait_loop > 1000 )); then
      echo client1 wait for client2 timeout;
      exit 3;
    fi
    echo round:$wget_client2_wait_loop wget_waiting http://client2-service:999/client2_ready.txt...; sleep 1;
    timeout -s 9 20s wget http://client2-service:999/client2_ready.txt
  done

  echo client node1 put ready flag to client node2
  echo ready > client1_ready.txt
  $APACHE_BINARY -u client1_ready.txt http://client2-service:999/client1_ready.txt > /dev/null
  echo go
 fi
fi

if [ -z "$(lscpu | grep Hypervisor)" ]; then
  echo test in local bare metal
  sleep 0;
  starttime=$(date +%s)
  if [ $CLIENT_CPU_LISTS != 0 ]; then
    for i in ${CLIENT_CPU_LISTS_ARRAY[*]}; do
      if [ $GETFILE != index.html ]; then
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      else
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -i -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      fi
    done
  else
    for (( i=$begin;i<=$end;i=i+1 )); do
      # -i: ab executes the HEAD request
      if [ $GETFILE != index.html ]; then
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      else
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -i -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      fi
    done
  fi
  waitstarttime=$(date +%s)
else
  echo test in cloud
  sleep 0;
  starttime=$(date +%s)
  if [ $CLIENT_CPU_LISTS != 0 ]; then
    for i in ${CLIENT_CPU_LISTS_ARRAY[*]}; do
      if [ $GETFILE != index.html ]; then
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      else
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -i -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      fi
    done
  else
    for (( i=$begin;i<=$end;i=i+1 )); do
      # -i: ab executes the HEAD request
      if [ $GETFILE != index.html ]; then
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      else
        taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -i -c $CONCURRENCY -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log &
      fi
    done
  fi
  waitstarttime=$(date +%s)
fi
  
testing_wait_loop_count=0
while [ "$(ps -aux | grep ab | grep $URL)" ]; do
  testing_wait_loop_count=$(( $testing_wait_loop_count + 1 ))
  sleep 5s;
  if (( testing_wait_loop_count > 800 )); then
    killall ab;
    killall -s 9 ab;
  fi
done
sync; sleep 2s; sync;

log_cps_ok=0
if [ $CLIENT_CPU_LISTS != 0 ]; then
  for j in ${CLIENT_CPU_LISTS_ARRAY[*]}; do
    if [ $(grep 'Requests per second' tmp${j}.log |awk '{print $4}') ]; then
      log_cps_ok=$(( $log_cps_ok + 1 ))
    fi
  done
else
  for (( j=$begin;j<=$end;j=j+1 )); do
    if [ $(grep 'Requests per second' tmp${j}.log |awk '{print $4}') ]; then
      log_cps_ok=$(( $log_cps_ok + 1 )) 
    fi
  done
fi
echo cps log OK number: $log_cps_ok

# check client node apache bench logs number both OK
LOCAL_TEST_RESULT=""
if [ $log_cps_ok == `expr $end - $begin + 1` ]; then
 LOCAL_TEST_RESULT="OK"
else
 LOCAL_TEST_RESULT="FAILED"
 if [ $CONCURRENCY -gt 20 ] ; then
   CONCURRENCY=$(( $CONCURRENCY - 10 ))
 fi
fi

REMOTE_TEST_RESULT=""
if [ $NODE == 3 ]; then
 if [ $CLIENT_ID == 2 ]; then
  echo $LOCAL_TEST_RESULT > /var/www/html/client2_cps_ok.txt
  while [ ! -s /var/www/html/client1_cps_ok.txt ]; do
    echo client node 2 wait for client node 1 result
	sleep 1;
  done
  REMOTE_TEST_RESULT=$(cat /var/www/html/client1_cps_ok.txt)
 else
  echo $LOCAL_TEST_RESULT > client1_cps_ok.txt
  $APACHE_BINARY -u client1_cps_ok.txt http://client2-service:999/client1_cps_ok.txt > /dev/null
  while [ ! -f "client2_cps_ok.txt" ] ; 
  do
   echo client1 waiting client2 result
   sleep 1;
   timeout -s 9 20s wget http://client2-service:999/client2_cps_ok.txt
  done
  REMOTE_TEST_RESULT=$(cat client2_cps_ok.txt)
 fi

  if [ "$LOCAL_TEST_RESULT" == "OK" ] && [ "$REMOTE_TEST_RESULT" == "OK" ] ; then
    echo local and remote apache bench testing log number both OK.
    break;
  fi
else
  if [ "$LOCAL_TEST_RESULT" == "OK" ] ; then
    break;
  fi
fi

done

if [ $CLIENT_CPU_LISTS != 0 ]; then
  for i in ${CLIENT_CPU_LISTS_ARRAY[*]}; do
    echo ========= core $i ab original log =========
    cat tmp${i}.log
  done
else
  for (( i=$begin;i<=$end;i=i+1 )); do
    echo ========= core $i ab original log =========
    cat tmp${i}.log
  done
fi

Request_Per_Second=$(grep 'Requests per second' tmp*.log |awk '{print $4}' |awk '{sum+=$1} END{print sum}')
Time_taken_for_tests=$(grep 'Time taken for tests' tmp*.log |awk '{print $5}' |awk -vclients="$end-$begin+1" '{sum+=$1} END{print "Time_taken_for_tests: " sum/clients}')
Complete_requests=$(grep 'Complete requests' tmp*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
Failed_requests=$(grep 'Failed requests' tmp*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
Total_transferred=$(grep 'Total transferred' tmp*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
HTML_transferred=$(grep 'HTML transferred' tmp*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')

if [ $CLIENT_ID == 2 ]; then
 echo "--- Client Node 2 Get final results for all $log_cps_ok vclients ---"

 echo Client_Node2_Configured_Core_Number: $CLIENT_CPU_NUM > /var/www/html/client2.log
 echo Client_Node2_Testing_Core_Number: $CLIENT_TESTING_REAL_NUM >> /var/www/html/client2.log
 echo Client_Node2_Launch_vclients_seconds: $(($waitstarttime - $starttime)) >> /var/www/html/client2.log
 echo Client_Node2_Reqeuest_per_vclient: $REQUESTS >> /var/www/html/client2.log
 echo Client_Node2_Concurrency_per_vclient: $CONCURRENCY >> /var/www/html/client2.log
 echo Client_Node2_Complete_requests: ${Complete_requests} >> /var/www/html/client2.log
 echo Client_Node2_Failed_requests: ${Failed_requests} >> /var/www/html/client2.log
 echo Client_Node2_requests_per_second: ${Request_Per_Second} >> /var/www/html/client2.log
 echo Client_Node2_Total_transferred_byte: ${Total_transferred} >> /var/www/html/client2.log
 echo Client_Node2_HTML_transferred_byte: ${HTML_transferred} >> /var/www/html/client2.log

else

 if [ $NODE == 3 ]; then
  wget_client2_wait_loop=0
  rm -f client2.log;
  while [ ! -f "client2.log" ] ; 
  do
    wget_client2_wait_loop=`expr $wget_client2_wait_loop + 1`
    if (( wget_client2_wait_loop > 200 )); then
      echo client wait for client2 log timeout;
      exit 3;
    fi
    sleep 5;
    timeout -s 9 20s wget http://client2-service:999/client2.log
  done
  echo client1 waiting client2 available done
 fi

 echo "--- Client Node 1 Get final results for all vclients ---"

 echo Nginx_Worker_Number-$CIPHER: $NGINX_WORKERS

 echo Client_Node1_Configured_Core_Number: $CLIENT_CPU_NUM
 echo Client_Node1_Testing_Core_Number: $CLIENT_TESTING_REAL_NUM
 echo Client_Node1_Launch_vclients_seconds: $(($waitstarttime - $starttime))
 echo Client_Node1_Reqeuest_per_vclient: $REQUESTS
 echo Client_Node1_Concurrency_per_vclient: $CONCURRENCY
 echo Client_Node1_Complete_requests: ${Complete_requests}
 echo Client_Node1_Failed_requests: ${Failed_requests}
 echo Client_Node1_requests_per_second: ${Request_Per_Second}
 echo Client_Node1_Total_transferred_byte: ${Total_transferred}
 echo Client_Node1_HTML_transferred_byte: ${HTML_transferred}

 total_cps2=0
 if [ $NODE == 3 ]; then
    cat client2.log
    total_cps2=$(grep 'requests_per_second' client2.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
 fi
 echo cps $total_cps2 > node2_cps_result
 echo cps $Request_Per_Second > node1_cps_result
 total_cps=$(grep 'cps' node*_cps_result |awk '{print $2}' |awk '{sum+=$1} END{print sum}')

for (( j=$begin;j<=$end;j=j+1 )); do
 if [ -s tmp${j}.log ]; then
  stress_latency_min=$(grep 'Total:' tmp${j}.log | awk '{print $2}')
  stress_latency_mean=$(grep 'Total:' tmp${j}.log | awk '{print $3}')
  stress_latency_stdv=$(grep 'Total:' tmp${j}.log | awk '{print $4}')
  stress_latency_median=$(grep 'Total:' tmp${j}.log | awk '{print $5}')
  stress_latency_max=$(grep 'Total:' tmp${j}.log | awk '{print $6}')
 
  echo Client_Stress_Latency_Min: $stress_latency_min
  echo Client_Stress_Latency_Mean: $stress_latency_mean
  echo Client_Stress_Latency_StdV: $stress_latency_stdv
  echo Client_Stress_Latency_Median: $stress_latency_median
  echo Client_Stress_Latency_Max: $stress_latency_max
  break;
 fi
done

 echo Client_Node_Total_Requests_per_second: $total_cps
 echo Test_case_cost_seconds: $(($(date +%s) - $starttime)) 

fi
#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

openssl version
NODE=${NODE:-2}
MODE=${MODE:-https}
NGINX_HOST=${NGINX_SERVICE_NAME:-nginx-server-service}
PORT=${PORT:-443}
APACHE_PATH=${APACHE_PATH:-"/home"}
APACHE_BINARY=ab
GETFILE=${GETFILE:-index.html}
CLIENT_CPU_LISTS=${CLIENT_CPU_LISTS:-0}
BIND_CORE=${BIND_CORE:-1C1T}

echo "client testing configurations:"
echo NODE:$NODE
echo MODE:$MODE
echo NGINX_HOST:$NGINX_HOST
echo PORT:$PORT
echo CLIENT_ID:$CLIENT_ID
echo GETFILE:$GETFILE
echo CLIENT_CPU_LISTS:$CLIENT_CPU_LISTS
echo SWEEPING:$SWEEPING
echo PACE:$PACE
echo BIND_CORE:$BIND_CORE

PROTOCOL=${PROTOCOL:-TLSv1.3}
CIPHER=${CIPHER:-AES128-GCM-SHA256}
CURVE=${CURVE:-secp384r1}
CERT=${CERT:-rsa2048}

# correct the format of input PROTOCOL
PROTOCOL=$(echo "$PROTOCOL" | sed 's/v//g')

echo PROTOCOL:$PROTOCOL
echo CIPHER:$CIPHER

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

whole_system_cores=`nproc`
system_last_core_id=`expr $whole_system_cores - 1`
echo system cores $whole_system_cores, core list 0 - $system_last_core_id

NGINX_WORKERS=${NGINX_WORKERS:-1}
if [[ $MAX_CORE_WORKER_CLIENT == "true" ]]; then
    NGINX_WORKERS=$whole_system_cores
    CLIENT_CPU_NUM=$whole_system_cores
else
    CLIENT_CPU_NUM=${CLIENT_CPU_NUM:-$NGINX_WORKERS}
fi
echo NGINX_WORKERS:$NGINX_WORKERS
echo CLIENT_CPU_NUM:$CLIENT_CPU_NUM

begin=0
if [ $NODE == 1 ]; then
  begin=$((NGINX_WORKERS + CORE_START))
  if [[ $BIND_CORE == "1C2T" ]]; then
    begin=$(lscpu | grep "NUMA node1 CPU(s):" | awk '{print $4}' | awk '{split($1, arr, ","); print arr[1]}' | awk '{split($1, arr, "-"); print arr[1]}')
  fi
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


function run(){
    concurrency=$1
    log_file=$2
    echo "-------------------------------------------------------------------"
    echo "--------- Start to run ab with concurrency $concurrency -----------"
    echo "-------------------------------------------------------------------"
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
          echo taskset -c ${i} ab -n $REQUESTS -q -r -c $concurrency -Z $CIPHER -f $PROTOCOL $URL
        else
          echo taskset -c ${i} ab -n $REQUESTS -q -r -i -c $concurrency -Z $CIPHER -f $PROTOCOL $URL
        fi
      done
    else
      for (( i=$begin;i<=$end;i=i+1 )); do
        if [ $GETFILE != index.html ]; then
          echo taskset -c ${i} ab -n $REQUESTS -q -r -c $concurrency -Z $CIPHER -f $PROTOCOL $URL
        else
          echo taskset -c ${i} ab -n $REQUESTS -q -r -i -c $concurrency -Z $CIPHER -f $PROTOCOL $URL
        fi
      done
    fi

    if [ $CLIENT_ID -ge 2 ]; then
     sed -i "s|listen 80|listen ${SERVICE_PORT}|" /usr/local/share/nginx/conf/nginx-http-with-upload.conf
     nginx -c /usr/local/share/nginx/conf/nginx-http-with-upload.conf
    fi

  for i in {1..90}; do

    seq=$i

    # clean up
    rm -f tmp*.log

    if [ $NODE -ge 3 ]; then
      LOCAL_TEST_RESULT="OK"
      echo $LOCAL_TEST_RESULT > /var/www/html/client${CLIENT_ID}_ready_$seq.txt
      if [ $CLIENT_ID == 1 ]; then
        for (( j=2 ; j<$NODE ; j++ ));
        do
          wget_client_wait_loop=0
          while [ ! -f "client${j}_ready_$seq.txt" ] ;
          do
            wget_client_wait_loop=$(( $wget_client_wait_loop + 1 ))
            if (( wget_client_wait_loop > 2000 )); then
              echo client${CLIENT_ID} wait for client${j} timeout;
              exit 3;
            fi
            echo client${CLIENT_ID} waiting client${j} ....
            sleep 5;
            let "port=1001-$j"
            timeout -s 9 20s wget http://client${j}-service:${port}/client${j}_ready_$seq.txt
          done
        done
        for (( j=2 ; j<$NODE ; j++ ));
        do
          let "port=1001-$j"
          curl http://client${j}-service:${port}/client1_ready_$seq.txt --upload-file /var/www/html/client1_ready_$seq.txt
        done
      else
        wget_client_wait_loop=0
        while [ ! -s /var/www/html/client1_ready_$seq.txt ]; do
          wget_client_wait_loop=$(( $wget_client_wait_loop + 1 ))
          if (( wget_client_wait_loop > 2000 )); then
            echo client${CLIENT_ID} wait for other client to ready timeout;
            exit 3;
          fi
          echo client node ${CLIENT_ID} wait for other client to be ready ...
          sleep 1;
        done
      fi

    fi

      sleep 0;
      starttime=$(date +%s)
      if [ $CLIENT_CPU_LISTS != 0 ]; then
        for i in ${CLIENT_CPU_LISTS_ARRAY[*]}; do
          if [ $GETFILE != index.html ]; then
            taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -c $concurrency -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log 2>>log_error.out &
          else
            taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -i -c $concurrency -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log 2>>log_error.out &
          fi
        done
      else
        for (( i=$begin;i<=$end;i=i+1 )); do
          # -i: ab executes the HEAD request
          if [ $GETFILE != index.html ]; then
            taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -c $concurrency -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log 2>>log_error.out &
          else
            taskset -c ${i} ${APACHE_BINARY} -n $REQUESTS -q -r -i -c $concurrency -Z $CIPHER -f $PROTOCOL $URL > tmp${i}.log 2>>log_error.out &
          fi
        done
      fi
      waitstarttime=$(date +%s)

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
    if [ $log_cps_ok == `expr $end - $begin + 1` ] || [ $log_cps_ok == ${#CLIENT_CPU_LISTS_ARRAY[@]} ] ; then
     LOCAL_TEST_RESULT="OK"
    else
     LOCAL_TEST_RESULT="FAILED"
     if [ $concurrency -gt 20 ] ; then
       concurrency=$(( $concurrency - 10 ))
     fi
    fi

    REMOTE_TEST_RESULT=""
    if [ $NODE -ge 3 ]; then
      OK_TEST_RESULT_COUNT=1
      if [ $CLIENT_ID == 1 ]; then
        echo $LOCAL_TEST_RESULT > client${CLIENT_ID}_cps_ok_$seq.txt
        for (( j=2 ; j<$NODE ; j++ ));
        do
          let "port=1001-$j"
          wget_client_wait_loop=0
          while [ ! -f "client${j}_cps_ok_$seq.txt" ] ;
          do
            wget_client_wait_loop=$(( $wget_client_wait_loop + 1 ))
            if (( wget_client_wait_loop > 2000 )); then
              echo client${CLIENT_ID} wait for client${j} result timeout;
              exit 3;
            fi
            echo "client$CLIENT_ID waiting client$j result"
            sleep 1;
            let "port=1001-$j"
            timeout -s 9 20s wget http://client${j}-service:${port}/client${j}_cps_ok_$seq.txt
          done
          REMOTE_TEST_RESULT=$(cat client${j}_cps_ok_$seq.txt)
          echo "remote result $REMOTE_TEST_RESULT $j "
          if [ "$REMOTE_TEST_RESULT" == "OK" ] ; then
            OK_TEST_RESULT_COUNT=$((OK_TEST_RESULT_COUNT+1))
          fi
        done
        if [ "$LOCAL_TEST_RESULT" == "OK" ] ; then
          OK_TEST_RESULT_COUNT=$((OK_TEST_RESULT_COUNT+1))
        fi
        if [ $OK_TEST_RESULT_COUNT == $NODE ]; then
          for (( j=2 ; j<$NODE ; j++ ));
          do
            let "port=1001-$j"
            $APACHE_BINARY -u client${CLIENT_ID}_cps_ok_$seq.txt http://client${j}-service:${port}/client${CLIENT_ID}_cps_ok_$seq.txt > /dev/null
          done
          break
        else
          echo "FAILED" > client${CLIENT_ID}_cps_ok_$seq.txt
          for (( j=2 ; j<$NODE ; j++ ));
          do
            let "port=1001-$j"
            $APACHE_BINARY -u client${CLIENT_ID}_cps_ok_$seq.txt http://client${j}-service:${port}/client${CLIENT_ID}_cps_ok_$seq.txt > /dev/null
          done
        fi

      else
        echo $LOCAL_TEST_RESULT > /var/www/html/client${CLIENT_ID}_cps_ok_$seq.txt
        while [ ! -s /var/www/html/client1_cps_ok_$seq.txt ]; do
          echo "client node ${CLIENT_ID} wait for client node 1 result"
          sleep 1;
        done
        REMOTE_TEST_RESULT=$(cat /var/www/html/client1_cps_ok_$seq.txt)
        if [ "$REMOTE_TEST_RESULT" == "OK" ] ; then
          echo "result ok, collect result"
          break
        fi
      fi
    else
      if [ "$LOCAL_TEST_RESULT" == "OK" ] ; then
        echo "result ok, collect result"
        break;
      fi
    fi

    echo "test result not ok"

    # clean up
    rm -f client?_cps_ok_$seq.txt
    rm -f client?_ready_$seq.txt
    rm -f /var/www/html/client?_cps_ok_$seq.txt
    rm -f /var/www/html/client?_ready_$seq.txt

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
    Transfer_rate=$(grep 'Transfer rate' tmp*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')

    if [ $CLIENT_ID -ge 2 ]; then
      echo "--- Client Node $CLIENT_ID Get final results for all $log_cps_ok vclients ---"

      echo Client_Node${CLIENT_ID}_Configured_Core_Number: $CLIENT_CPU_NUM > /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Testing_Core_Number: $CLIENT_TESTING_REAL_NUM >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Launch_vclients_seconds: $(($waitstarttime - $starttime)) >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Reqeuest_per_vclient: $REQUESTS >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Concurrency_per_vclient: $concurrency >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Complete_requests: ${Complete_requests} >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Failed_requests: ${Failed_requests} >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_requests_per_second: ${Request_Per_Second} >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_Total_transferred_byte: ${Total_transferred} >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_HTML_transferred_byte: ${HTML_transferred} >> /var/www/html/client${CLIENT_ID}.log
      echo Client_Node${CLIENT_ID}_HTML_transferred_rate: ${Transfer_rate} >> /var/www/html/client${CLIENT_ID}.log

    else

     if [ $NODE -ge 3 ]; then
      for (( i=2 ; i<$NODE ; i++ ));
      do
        wget_client_wait_loop=0
        rm -f client${i}.log;
        while [ ! -f "client${i}.log" ] ;
        do
          wget_client_wait_loop=`expr $wget_client_wait_loop + 1`
          if (( wget_client_wait_loop > 200 )); then
            echo client wait for client$i log timeout;
            exit 3;
          fi
          sleep 5;
          let "port=1001-$i"
          timeout -s 9 20s wget http://client${i}-service:${port}/client${i}.log
        done
        echo client${CLIENT_ID} waiting client${i} available done
      done
     fi

     echo "--- Client Node 1 Get final results for all vclients ---"

     echo Nginx_Worker_Number-$CIPHER: $NGINX_WORKERS | tee -a $log_file

     echo Client_Node1_Configured_Core_Number: $CLIENT_CPU_NUM | tee -a $log_file
     echo Client_Node1_Testing_Core_Number: $CLIENT_TESTING_REAL_NUM | tee -a $log_file
     echo Client_Node1_Launch_vclients_seconds: $(($waitstarttime - $starttime)) | tee -a $log_file
     echo Client_Node1_Reqeuest_per_vclient: $REQUESTS | tee -a $log_file
     echo Client_Node1_Concurrency_per_vclient: $concurrency | tee -a $log_file
     echo Client_Node1_Complete_requests: ${Complete_requests} | tee -a $log_file
     echo Client_Node1_Failed_requests: ${Failed_requests} | tee -a $log_file
     echo Client_Node1_requests_per_second: ${Request_Per_Second} | tee -a $log_file
     echo Client_Node1_Total_transferred_byte: ${Total_transferred} | tee -a $log_file
     echo Client_Node1_HTML_transferred_byte: ${HTML_transferred} | tee -a $log_file
     echo Client_Node1_HTML_transferred_rate: ${Transfer_rate} | tee -a $log_file

     if [ $NODE -ge 3 ]; then
        for (( i=2 ; i<$NODE ; i++ ));
        do
          cat client${i}.log
          total_cps=$(grep 'requests_per_second' client${i}.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
          total_throughput=$(grep 'transferred_rate' client${i}.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
          echo cps $total_cps > node${i}_cps_result
          echo throughput $total_throughput > node${i}_tpt_result
        done
     fi
     echo cps $Request_Per_Second > node1_cps_result
     echo throughput $Transfer_rate > node1_tpt_result
     total_cps=$(grep 'cps' node*_cps_result |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
     total_throughput=$(grep 'throughput' node*_tpt_result |awk '{print $2}' |awk '{sum+=$1} END{print sum}')

    for (( j=$begin;j<=$end;j=j+1 )); do
     if [ -s tmp${j}.log ]; then
      stress_latency_min=$(grep 'Total:' tmp${j}.log | awk '{print $2}')
      stress_latency_mean=$(grep 'Total:' tmp${j}.log | awk '{print $3}')
      stress_latency_stdv=$(grep 'Total:' tmp${j}.log | awk '{print $4}')
      stress_latency_median=$(grep 'Total:' tmp${j}.log | awk '{print $5}')
      stress_latency_max=$(grep 'Total:' tmp${j}.log | awk '{print $6}')

      echo Client_Stress_Latency_Min: $stress_latency_min | tee -a $log_file
      echo Client_Stress_Latency_Mean: $stress_latency_mean | tee -a $log_file
      echo Client_Stress_Latency_StdV: $stress_latency_stdv | tee -a $log_file
      echo Client_Stress_Latency_Median: $stress_latency_median | tee -a $log_file
      echo Client_Stress_Latency_Max: $stress_latency_max | tee -a $log_file
      break;
     fi
    done

     echo Client_Node_Total_Requests_per_second: $total_cps | tee -a $log_file
     echo Client_Node_Total_HTML_transferred_rate: $total_throughput | tee -a $log_file
     echo Test_case_cost_seconds: $(($(date +%s) - $starttime)) | tee -a $log_file

    fi
}

#If sweeping is off, run benchmark with default concurrency
if [[ $SWEEPING == "off" ]]; then
    run $CONCURRENCY concurrency_max.log
#Sweeping for concurrency
elif [[ $SWEEPING == "on" ]]; then
    start=$CONCURRENCY
    for i in {0..9}; do
        concurrency=$((start + i * $PACE ))
        log_file=concurrency_$concurrency.log
        run $concurrency $log_file
    done
    #Select the best result
    max=0
    for f in concurrency*.log; do
        if [ -r "$f" ]; then
            r="$(grep "Client_Node_Total_Requests_per_second: " "$f" | awk -v m=$max '{if($2>m)print$2}')"
            if [ -n "$r" ]; then
                max="$r"
                cp -f "$f" concurrency_max.log
            fi
        fi
    done
fi

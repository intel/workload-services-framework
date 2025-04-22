#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DURATION=${DURATION:-30}
URLS=${URLS:-/WordpressTarget.urls}
NPROC=${NPROC:-$(nproc)}

# Kernel Configuration
# sysctl -w net.core.netdev_max_backlog=655560 || true
# sysctl -w net.core.somaxconn=65535 || true
# sysctl -w net.ipv4.tcp_max_syn_backlog=131072 || true
sysctl -w net.ipv4.tcp_tw_reuse=1 || true

# set max open file descriptor unlimited
ulimit -n $((1024 * 1024))

if [ $NPROC -lt 8 ]; then
    echo "The number of CPU core is ${NPROC}. Run entrypoint test."
    NUSERS=${NUSERS:-10}
fi

echo "NUSERS: $NUSERS"
echo "httpmode: $HTTPMODE"

wait_for_completion() {
  testing_wait_loop_count=0
  while [ "$(ps -aux | grep 'siege -c' | grep '.urls' )" ]; do
    testing_wait_loop_count=$(( $testing_wait_loop_count + 1 ))
    sleep 5s;
    if (( testing_wait_loop_count > DURATION )); then
      pkill -9 siege;
    fi
    echo "waiting for siege run to finish"
  done
  sync; sleep 2s; sync;
}

function warmup(){
    echo "------Running Warm up ------ "
    for i in {1..3}; do
        echo "------[${i}/20]:Starting Siege for single request warmup ------"
        #timeout -s 9 60s siege -c1 -r300 -b -f $URLS 2>&1 | tee warmup1.log;
        for i in $(seq 0 $((INSTANCE_COUNT - 1))); do
                INST_URLS=$i.urls
                timeout -s 9 60s siege -c1 -r300 -b -f $INST_URLS  > warmup1_instance$i.log 2>&1 &
        done
        wait_for_completion
        echo "------[${i}/20]:Starting Siege for multi request warmup ------"
        #timeout -s 9 60s siege -c200 -t30S -b -f $URLS 2>&1 | tee warmup2.log;
        for i in $(seq 0 $((INSTANCE_COUNT - 1))); do
                INST_URLS=$i.urls
                timeout -s 9 60s siege -c200 -t30S -b -f $INST_URLS  > warmup2_instance$i.log 2>&1 &
        done
        wait_for_completion
        warmup1_total_transactions=$(grep 'Transactions:' warmup1_instance*.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
        warmup1_total_transactions=$(grep 'Transactions:' warmup2_instance*.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
        if [[ $warmup1_total_transactions -gt 0 && $warmup1_total_transactions -gt 0 ]]; then
                echo "-----Warm up finished. ------ "
                break
        fi
        echo "------ Retry warmup[${i}] ------"
        sleep 120s
    done
}

function copy_wp_log(){
    for i in $(seq 0 $((INSTANCE_COUNT - 1))); do
        port=$((NGINX_BASE_PORT + $i))
        if [[ $HTTPMODE == "http" ]]; then
            url="http://siteurl-${i}:${port}"
        else
            url="https://siteurl-${i}:${port}"
        fi
        curl -o wordpress_instance${i}.log $url/output.log -k
    done
}

function siege_run(){
    echo "begin_region_of_interest"
    if [[ ${BENCHMARK_MODE} == "requests" ]]; then
        echo "Fixed requests number test case"
        echo "[${itr}/20]: siege -c $NUSERS -r ${REQUESTS_NUM} -b -f $URLS"
        #timeout -s 9 10m siege -c $NUSERS -r ${REQUESTS_NUM} -b -f $URLS  2>&1 | tee $1.log;
        for i in $(seq 0 $((INSTANCE_COUNT - 1))); do
                INST_URLS=$i.urls
                timeout -s 9 $(( DURATION * 2 ))s siege -c $NUSERS -r ${REQUESTS_NUM} -b -f $INST_URLS -v > instance$i.log 2>&1 &
        done
    else
        echo "[${itr}/20]: siege -c $NUSERS -t ${DURATION}S -b -f $URLS"
        #timeout -s 9 $(( DURATION * 2 ))s siege -c $NUSERS -t ${DURATION}S -b -f $URLS -v 2>&1 | tee $1.log | grep -v "HTTP";
        for i in $(seq 0 $((INSTANCE_COUNT - 1))); do
                INST_URLS=$i.urls
                timeout -s 9 $(( DURATION * 2 ))s siege -c $NUSERS -t ${DURATION}S -b -f $INST_URLS -v > instance$i.log 2>&1 &
        done
    fi
    wait_for_completion
    Total_transaction_rate=$(grep 'Transaction rate:' instance*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
    Total_transaction=$(grep 'Transactions:' instance*.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
    Total_data_transferred=$(grep 'Data transferred:' instance*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
    Total_throughput=$(grep 'Throughput:' instance*.log |awk '{print $2}' |awk '{sum+=$1} END{print sum}')
    Total_successful_transactions=$(grep 'Successful transactions:' instance*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
    Total_failed_transactions=$(grep 'Failed transactions:' instance*.log |awk '{print $3}' |awk '{sum+=$1} END{print sum}')
    Availability=$(grep 'Availability:' instance0.log |awk '{print $2}')
    Elapsed_time=$(grep 'Elapsed time:' instance0.log |awk '{print $3}')
    Response_time=$(grep 'Response time:' instance0.log |awk '{print $3}')
    Concurrency=$(grep 'Concurrency:' instance0.log |awk '{print $2}')
    Longest_transaction=$(grep 'Longest transaction:' instance0.log |awk '{print $3}')
    Shortest_transaction=$(grep 'Shortest transaction:' instance0.log |awk '{print $3}')
    echo "Final Result:"
    echo "Transactions: $Total_transaction hits" | tee -a $1.log
    echo "Availability: $Availability %" | tee -a $1.log
    echo "Elapsed time: $Elapsed_time secs" | tee -a $1.log
    echo "Data transferred: $Total_data_transferred MB" | tee -a $1.log
    echo "Response time: $Response_time secs" | tee -a $1.log
    echo "Transaction rate: $Total_transaction_rate trans/sec" | tee -a $1.log
    echo "Throughput: $Total_throughput MB/sec" | tee -a $1.log
    echo "Concurrency: $Concurrency" | tee -a $1.log
    echo "Successful transactions: $Total_successful_transactions" | tee -a $1.log
    echo "Failed transactions: $Total_failed_transactions" | tee -a $1.log
    echo "Longest transaction: $Longest_transaction" | tee -a $1.log
    echo "Shortest transaction: $Shortest_transaction" | tee -a $1.log
    if  [ -z "$(grep -E 'Transactions:\s*0 hits' $1.log)" ] && [ -n "$(grep -E 'Failed transactions:\s*0' $1.log)" ]; then
            echo "end_region_of_interest"
            return 0
    fi

    if [ "$1" == "siege_performance" ]; then
        mv $1.log $1.$(date +"%Y%m%d%H%M%S").log
    fi
    echo "end_region_of_interest"
    echo " ------ Siege failed! ------"
    sleep 120s
    return 1
}

echo "------ Running tests ------ "
# Run tests
if [ "${NUSERS}" != "auto" ]; then
    echo "The number of User  is ${NUSERS}."
    for itr in {1..10}; do
        warmup
        if siege_run siege_performance;then
           copy_wp_log
           exit 0
        fi
    done
else
    for j in {2..3}; do
        NUSERS=$(( j * 25 ))
        echo "The number of User is ${NUSERS}."
        for itr in {1..10}; do
            warmup
            if siege_run run${j};then
                break
            fi
            rm -f run${j}.log
        done
        sleep 120s
    done

    echo "------ Picking the best performance ------"
    max=0
    for f in run*.log; do
        if [ -r "$f" ]; then
            r="$(grep "Transaction rate:" "$f" | awk -v m=$max '{if($3>m)print$3}')"
            if [ -n "$r" ]; then
                max="$r"
                cp -f "$f" siege_performance.log
            fi
        fi
    done
    echo "----- All tests finished! ------"
    copy_wp_log
    exit 0
fi
echo "------ Test failed ------"
copy_wp_log
exit 3
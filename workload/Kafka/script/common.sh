#!/bin/bash

# This is the common script used to provide generic functions

function get_numa_cmd() {
    NUMACTL_OPTIONS=$(eval echo \${K_$1_NUMACTL_OPTIONS})
    if [[ -n $NUMACTL_OPTIONS ]]; then
        echo "numactl ${NUMACTL_OPTIONS}"
        echo "numactl ${NUMACTL_OPTIONS} enable for $1" >&2
    else
        echo "numactl not enable for $1" >&2
    fi
}

function wait_zk(){
    zkList=(${K_ZK_SERVER//,/ })
    zkNotReady=true
    zkTestMaxCount=100
    testCount=0
    while [[ $zkNotReady == true && $testCount -lt $zkTestMaxCount ]]
    do
        echo "waiting for zk"
        zkNotReady=false
        for zk in ${zkList[@]}
        do
            nc -z -w5 ${zk//:/ } 2>/dev/null
            if [[ $? -ne 0 ]];then
                zkNotReady=true
                break
            fi
        done
        ((testCount++))
        sleep 5
    done
    if [[ $zkNotReady == true ]];then
        echo "zk cluster is not ready"
        exit 1
    fi
}

function wait_broker(){
    brokerList=(${K_KAFKA_SERVER//,/ })
    brokerNotReady=true
    testCount=0
    while [[ $brokerNotReady == true ]]
    do
        echo "waiting for broker"
        brokerNotReady=false
        for broker in ${brokerList[@]}
        do
            nc -z -w5 ${broker//:/ } 2>/dev/null
            if [[ $? -ne 0 ]];then
                brokerNotReady=true
                break
            fi
        done
        ((testCount++))
        sleep 5
    done
}

#get kafka broker free space stored in zk
function get_server_free_space(){ 
    for i in {1..10}
    do
    
        free_space=`${KAFKA_HOME}/bin/zookeeper-shell.sh ${K_ZK_SERVER}  get  /kafka_server_free_space 2>/dev/null |tail -n 1`
        if [[ "$free_space" -gt 0 ]] 2>/dev/null ;then break;fi
        free_space=""
        sleep 5
    done
    set -e
    if [[ .${free_space} == "." ]];then 
        echo "fail to get server free space. exiting"
        exit 1
    fi
    echo $free_space
}

#save kafka broker free space space to zk
function update_server_free_space(){
    memory=`free |grep Mem|awk '{printf "%.0f\n", $2*1024}'`
    free_disk=`df ${BASE_DIR}/kafka_logs | tail -n 1|awk '{printf "%.0f\n", $4*1024}'`
    free_space=$((memory < free_disk ? memory : free_disk))
    echo "broker side free memory: " $memory
    echo "broker side free disk: " $free_disk
    for i in {1..10}
    do
        echo "update_server_free_space:" $free_space
        ${KAFKA_HOME}/bin/zookeeper-shell.sh ${K_ZK_SERVER}  create /kafka_server_free_space $free_space 2>/dev/null
        if [[ $? -eq 0 ]]; then
            break
        fi
        sleep 5
    done
    get_server_free_space
}

#set the num records under system limition
function limit_num_records(){
    free_space=`get_server_free_space`
    echo "free_space: " $free_space
    records_limit_per_producer=`echo "$K_PRODUCERS" "$K_RECORD_SIZE" "$free_space" |awk '{printf "%.0f\n", $3/$2/$1*0.6}'`
    if [[ $K_NUM_RECORDS -gt $records_limit_per_producer ]]; then K_NUM_RECORDS=$records_limit_per_producer; fi
    echo "K_NUM_RECORDS: " $K_NUM_RECORDS
}


#get kafka broker network bandwith stored in zk
function get_server_network_bandwith(){ 
    for i in {1..10}
    do
    
        net_bandwith=`${KAFKA_HOME}/bin/zookeeper-shell.sh ${K_ZK_SERVER}  get  /kafka_server_network_bandwith 2>/dev/null |tail -n 1`
        if [[ "$net_bandwith" -gt 0 ]] 2>/dev/null ;then break;fi
        net_bandwith=""
        sleep 5
    done
    set -e
    if [[ .${net_bandwith} == "." ]];then 
        echo "fail to get server network bandwith. exiting"
        exit 1
    fi
    echo $net_bandwith
}

#save kafka broker network bandwith to zk
function update_server_network_bandwith(){
    ip=`nslookup ${POD_NAME}.zookeeper-kafka-server-service |grep Address|tail -n 1|awk '{print $2}'`
    net_dev=`ifconfig |grep " ${ip} " -B 1 |head -n 1|awk -F : '{print $1}'`
    net_bandwith=`ethtool ${net_dev} |grep Speed |awk '{print $2}'|awk -F M '{print $1}'`
    if [[ .${net_bandwith} == "." || ${net_bandwith} == "Unknown!" ]];then
        echo "fail to get net_bandwith, so not limit"
        net_bandwith="10000000"  #set big enough to unlimit
    fi
    for i in {1..10}
    do
        echo "update_server_network_bandwith:" $net_bandwith
        ${KAFKA_HOME}/bin/zookeeper-shell.sh ${K_ZK_SERVER}  create /kafka_server_network_bandwith $net_bandwith 2>/dev/null
        if [[ $? -eq 0 ]]; then
            break
        fi
        sleep 5
    done
    get_server_network_bandwith
}


#set the producers under system limitation
function limit_producers(){
    net_bandwith=`get_server_network_bandwith`
    bandwith_per_producer=100
    echo "net_bandwith: " $net_bandwith
    producer_limit_count=`echo "$net_bandwith" $bandwith_per_producer |awk '{printf "%.0f\n", $1/$2}'`
    if [[ $K_PRODUCERS -gt $producer_limit_count ]]; then K_PRODUCERS=$producer_limit_count; fi
    echo "K_PRODUCERS: " $K_PRODUCERS
}

function parser_ip_by_domain(){
    ip=`host $1|awk '{print $NF}'`
    until check_ip ${ip} 
    do
        sleep 2
        ip=`host $1|awk '{print $NF}'`
    done
    echo $ip
}

function check_ip(){
        IP=$@
        VALID_CHECK=$(echo $IP|awk -F. '$1 ~ /^[0-9.]+$/ && $2 ~ /^[0-9.]+$/ && $3 ~ /^[0-9.]+$/ && $4 ~ /^[0-9.]+$/ && $1<=255 && $2<=255 && $3<=255 && $4<=255 {print "yes"}')
        if [[ $VALID_CHECK == "yes" ]]; then
                return 0
        else
                return 1
        fi
}

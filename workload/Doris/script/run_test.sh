#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

source ./libs.sh

function init_var(){
    fe_ip=`parser_ip_by_domain doris-fe-0.doris-fe-service`
}

function waiting_fe() {
    until curl -s http://doris-fe-0.doris-fe-service:8030/api/bootstrap | jq .msg |grep success
    do
        echo "waiting for doris fe to start"
        sleep 5
    done
}

function waiting_be() {
    for (( i=0; i < ${K_DORIS_BE_NUM}; i++ ))
    do 
        until curl -s http://doris-be-${i}.doris-be-service:8040/api/health |jq .status |grep OK
        do
            echo "waiting for doris be ${i} to start"
            sleep 5
        done
    done 
}

function add_be_to_cluster() {
    for (( i=0; i < ${K_DORIS_BE_NUM}; i++ ))
    do 
        be_ip=`host doris-be-${i}.doris-be-service|awk '{print $NF}'`
        sql="ALTER SYSTEM ADD BACKEND \"${be_ip}:9050\";"
        echo $sql | mysql -h ${fe_ip} -P 9030 -uroot
    done 
}

function gen_ssb_data() {
    cd /home/apache-doris-src/tools/ssb-tools/bin
    sed -i "s|^export FE_HOST=.*$|export FE_HOST=\'${fe_ip}\'|" ../conf/doris-cluster.conf
    echo "generate ssb data"
    sh gen-ssb-data.sh -s ${K_DATA_SIZE_FACTOR} -c ${K_DATA_GEN_THERADS}
    sh create-ssb-tables.sh
    echo "load ssb data"
    sh load-ssb-data.sh
    echo "waiting for compaction"
    for (( i=0; i < ${K_DORIS_BE_NUM}; i++ ))
    do 
        until curl -s http://doris-be-${i}.doris-be-service:8040/api/compaction/run_status | jq '.CumulativeCompaction|to_entries|.[]|.value'|grep '\[\]'
        do
            echo "waiting for doris be ${i} compaction to finish"
            sleep 10
        done
    done
    echo "ssb data is ready"
}

function benchmark() {
    cd /home/apache-doris-src/tools/ssb-tools/bin
    echo "ssb queries start"
    sh run-ssb-queries.sh
    echo "ssb queries end"
    echo "flat ssb queries start"
    sh run-ssb-flat-queries.sh
    echo "flat ssb queries end"
}

echo "waiting for doris culster to be ready"
waiting_fe
waiting_be
echo "both fe and be are ready"
init_var
add_be_to_cluster
echo "doris culster is ready"
gen_ssb_data
echo "begin region of interest"
benchmark
echo "end region of interest"
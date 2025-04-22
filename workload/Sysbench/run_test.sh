#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#bound to physical cores
run_memory_testing_bound_physical_cores() {
    #get physical cores
    readarray -t physical_core_list < <(lscpu -p | grep -v '#'|awk -F ',' '{print $2}')
    #remove duplicate cores, if have
    declare -A uniqueArray
    for core in ${physical_core_list[@]}; do
        uniqueArray["$core"]=1
    done
    physical_core_list=(${!uniqueArray[@]})
    pyhsical_core_num=${#physical_core_list[@]}
    if [ $THREADS -gt  $pyhsical_core_num ]; then
        THREADS=$pyhsical_core_num
    fi
    physical_core_list_str=$(echo ${!uniqueArray[@]} |  sed 's/ /,/g')
    echo "pyhsical_core_num:$pyhsical_core_num, THREADS:$THREADS"
    echo "physical_core_list_str: $physical_core_list_str"
    echo "assignable_size:$assignable_size MEMORY_TOTAL_SIZE:$MEMORY_TOTAL_SIZE"

    numactl --physcpubin=${physical_core_list_str} sysbench --threads=$THREADS --time=$TIME --memory-block-size=$MEMORY_BLOCK_SIZE \
            --memory-total-size=$MEMORY_TOTAL_SIZE --memory-scope=$MEMORY_SCOPE --memory-oper=$MEMORY_OPER --memory-access-mode=$MEMORY_ACCESS_MODE $MODE run
}

#no bound
run_memory_testing() {
    echo "THREADS:$THREADS"
    echo "MEMORY_TOTAL_SIZE:$MEMORY_TOTAL_SIZE"

    sysbench --threads=$THREADS --time=$TIME --memory-block-size=$MEMORY_BLOCK_SIZE \
            --memory-total-size=$MEMORY_TOTAL_SIZE --memory-scope=$MEMORY_SCOPE --memory-oper=$MEMORY_OPER --memory-access-mode=$MEMORY_ACCESS_MODE $MODE run
}

wait_mysql_start() {
    for ((;;)); do
        state=`mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} ping | grep 'mysqld is alive' || [[ $? == 1 ]]`
            if [ -z "$state" ]; then
                echo "Waiting mysql start..."
                sleep 2
            else
                echo "Mysql started successfully."
                break
            fi
    done
}

ARGS="$@"
echo "Begin performance testing"
if  [ $MODE == "cpu" ];then
    sysbench --threads=$THREADS --time=$TIME --cpu-max-prime=$CPU_MAX_PRIME $MODE run
elif  [ $MODE == "mutex" ];then
    sysbench --threads=$THREADS  --mutex-locks=${MUTEX_LOCKS} $MODE run
elif [ $MODE == "memory" ];then
    run_memory_testing
elif [ $MODE == "mysql" ];then
    export MYSQL_ROOT_PASSWORD="Mysql@123"
    touch /var/log/mysql/error.log;chmod 766 /var/log/mysql/error.log
    nohup /usr/local/bin/docker-entrypoint.sh mysqld &
    wait_mysql_start
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "create database sbtest"
    sysbench --db-driver=mysql --mysql-user=root --mysql_password=$MYSQL_ROOT_PASSWORD --mysql-db=sbtest --mysql-host=localhost --mysql-port=3306 --tables=$TABLES_NUM --table-size=$TABLE_SIZE /usr/share/sysbench/oltp_read_write.lua prepare
    sysbench --threads=$THREADS --events=0 --time=$TIME --mysql-host=localhost --mysql-user=root --mysql-password=$MYSQL_ROOT_PASSWORD --tables=$TABLES_NUM --delete_inserts=10 --index_updates=10 --non_index_updates=10 --table-size=$TABLE_SIZE --db-ps-mode=disable --report-interval=1 /usr/share/sysbench/oltp_read_write.lua run
    mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} shutdown
else
    echo "The test doesn't support!"
fi
echo "End performance testing"

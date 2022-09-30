#!/bin/bash

if ${DEBUG:-false}; then
    echo "HAMMERDB_INSTALL_DIR: ${HAMMERDB_INSTALL_DIR}"
    echo "DB_TYPE: ${DB_TYPE}"
    echo "TPCC_TCL_SCRIPT_PATH: ${TPCC_TCL_SCRIPT_PATH}"
fi

CPU_CORES=$(nproc)
if [[ "$TPCC_THREADS_BUILD_SCHEMA" -gt  "$CPU_CORES" ]]; then
    echo "Warning: specified build schema thread count $TPCC_THREADS_BUILD_SCHEMA greater than current cpu cores $CPU_CORES adjust to current cpu cores"
    TPCC_THREADS_BUILD_SCHEMA="$CPU_CORES"
fi

# Only on single node can get cpu cores
if ${RUN_SINGLE_NODE:-false}; then
    # if not specified, generate default value(s)
    if [[ -z "$TPCC_HAMMER_NUM_VIRTUAL_USERS" ]]; then
        source /common.sh
        echo "Info: no virtual user specified, auto-gen by current cpu cores $CPU_CORES"
        algo=${TPCC_HAMMER_NUM_VIRTUAL_USERS_GEN_ALGORITHM:-"fixed"}
        algo_func=$(
            case $algo in
                baseline)
                    echo "get_baseline_vuser_list"
                    ;;
                advanced_binary_search)
                    echo "get_advanced_binarysearch_vuser_list"
                    ;;
                binary_search)
                    echo "get_binarysearch_vuser_list"
                    ;;
                *)
                    echo "get_fixed_vuser_list"
                    ;;
            esac
        )
        TPCC_HAMMER_NUM_VIRTUAL_USERS="$($algo_func)"
    fi
fi
echo "TPCC_HAMMER_NUM_VIRTUAL_USERS=$TPCC_HAMMER_NUM_VIRTUAL_USERS"

function buildschema_mysql() {
    cat >"${TPCC_TCL_SCRIPT_PATH}/build_schema.tcl"<<EOF
#!/bin/tclsh
puts "SETTING CONFIGURATION"
global complete
proc wait_to_complete {} {
    global complete
    set complete [vucomplete]
    puts "Is it complete ?: \$complete"
    if {!\$complete} {
        after $TPCC_WAIT_COMPLETE_MILLSECONDS wait_to_complete
    } else {
        puts "BUILD SCHEMA COMPLETE"
        exit
    }
}
dbset db mysql
dbset bm TPC-C
diset connection mysql_host $DB_HOST
diset connection mysql_port $DB_PORT
diset connection mysql_socket /tmp/mysql.sock
diset tpcc mysql_user $MYSQL_USER
diset tpcc mysql_pass $MYSQL_ROOT_PASSWORD
diset tpcc mysql_count_ware $TPCC_NUM_WAREHOUSES
diset tpcc mysql_partition true
diset tpcc mysql_num_vu $TPCC_THREADS_BUILD_SCHEMA
diset tpcc mysql_storage_engine $MYSQL_STORAGE_ENGINE
print dict
buildschema
wait_to_complete
vwait forever
EOF
}

function rumhammer_mysql() {
    cat >"${TPCC_TCL_SCRIPT_PATH}/run_timer.tcl"<<EOF
#!/bin/tclsh
proc runtimer { seconds } {
    set x 0
    set timerstop 0
    while {!\$timerstop} {
        incr x
        after 1000
        if { ![ expr {\$x % 60} ] } {
            set y [ expr \$x / 60 ]
            puts "Timer: \$y minutes elapsed"
        }
        update
        if {  [ vucomplete ] || \$x eq \$seconds } {
            set timerstop 1
        }
    }
    return
}
puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C
diset connection mysql_host $DB_HOST
diset connection mysql_port $DB_PORT
diset tpcc mysql_user $MYSQL_USER
diset tpcc mysql_pass $MYSQL_ROOT_PASSWORD
diset tpcc mysql_driver timed
diset tpcc mysql_rampup $TPCC_MINUTES_OF_RAMPUP
diset tpcc mysql_duration $TPCC_MINUTES_OF_DURATION
diset tpcc mysql_total_iterations $TPCC_TOTAL_ITERATIONS
diset tpcc mysql_async_scale ${TPCC_ASYNC_SCALE:-false}
diset tpcc mysql_connect_pool ${TPCC_CONNECT_POOL:-false}
vuset logtotemp 1
vuset unique 1
loadscript
puts "SEQUENCE STARTED"
foreach z [ split "$TPCC_HAMMER_NUM_VIRTUAL_USERS" "_" ] {
    puts "\$z VU TEST"
    vuset vu \$z
    vucreate
    vurun
    runtimer $TPCC_RUNTIMER_SECONDS
    vudestroy
    after $TPCC_WAIT_COMPLETE_MILLSECONDS
}
puts "TEST SEQUENCE COMPLETE"
exit
EOF
}

if [[ ! -d "$TPCC_TCL_SCRIPT_PATH" ]]; then
    mkdir -p "$TPCC_TCL_SCRIPT_PATH"
fi

if [[ "$DB_TYPE" == "mysql" ]]; then
    buildschema_mysql
    rumhammer_mysql
fi

# Make sure with a stable connection to database server
echo "Checking if database connection is stable..."
counter=0
until ((counter >= ${TPCC_INIT_MAX_WAIT_SECONDS:-5})); do
    nc -z -w5 $DB_HOST $DB_PORT
    if [ $? -eq 0 ]; then
        ((counter++))
    else
        echo "database service connection is unstable, retry"
        counter=0
    fi
    sleep 1
done
echo "Database connection is stable for $counter seconds"

cd ${HAMMERDB_INSTALL_DIR}

### numactl bind core logic
lscpu -p=CPU,NODE|sed -e '/^#/d' > /tmp/cpu_numa_map
NUMACTL_OPTIONS=""
if ${RUN_SINGLE_NODE:-true}; then
    # on single node
    if ${ENABLE_SOCKET_BIND:-true}; then
        system_cores=$(nproc)
        if [[ "$system_cores" -le 1 ]]; then
            echo "Only $system_cores cores, skip to balance"
        else
            nodes=$(lscpu | awk '/^NUMA node\(s\)/{print $3'})
            SERVER_CORE_NEEDED_FACTOR=${SERVER_CORE_NEEDED_FACTOR:-0.9}
            SERVER_CORE_NEEDED=$(echo "$system_cores $SERVER_CORE_NEEDED_FACTOR" |awk '{ printf("%d\n",$1 * $2) }')
            CLIENT_CORE_NEEDED=$((system_cores - SERVER_CORE_NEEDED))
            CLIENT_CORE_NEEDED_LESS=true # assume client need less core
            if [[ "$CLIENT_CORE_NEEDED" -gt "$SERVER_CORE_NEEDED" ]]; then
                CLIENT_CORE_NEEDED_LESS=false
            fi
            # caculate which cores will be used
            HALF_SYSTEM_CORES=$(( system_cores / 2 ))
            for i in $(seq 0 $((HALF_SYSTEM_CORES - 1)))
            do
                if [[ $CLIENT_CORE_NEEDED_LESS && "$i" -ge "$CLIENT_CORE_NEEDED" ]]; then
                    break
                fi
                nth_core_on_node=$(((2 * (i / nodes)) + 1))
                core=$(grep ",$((i % nodes))" /tmp/cpu_numa_map | sed "${nth_core_on_node}q;d" | awk -F ',' '{print $1}')
                if [[ ! $CLIENT_CORE_NEEDED_LESS && "$i" -ge "$SERVER_CORE_NEEDED" ]]; then
                    core_list+=($core) # assign server leftover cores to client
                fi
                core_list+=($((core+1)))
            done
            echo "Run on single node, system online cores: $system_cores, numa nodes: $nodes, server core needed factor: $SERVER_CORE_NEEDED_FACTOR, client core needed: ${#core_list[@]}, server core needed: $SERVER_CORE_NEEDED"
            NUMACTL_OPTIONS="numactl --physcpubind=$(echo "${core_list[@]}"|tr ' ' ',') --localalloc"
        fi
    else
        echo "Run on single node, socket bind disabled, skip to bind"
    fi
else
    # on multi-node
    if ${ENABLE_RPSRFS_AFFINITY:-true}; then
        echo "Enable rps/rfs on client side"
        source /network_rps_tuning.sh # enable network RPS tunning on multi-node
    fi
    if ${ENABLE_SOCKET_BIND:-true}; then
        DEFAULT_NODES=$(lscpu |awk '/^NUMA node[0-9]+ CPU\(s\)/{split($2, result, "node"); print result[2]}' |tr '\n' ',')
        if [[ "${DEFAULT_NODES}" =~ ^.*,$ ]]; then
            DEFAULT_NODES=${DEFAULT_NODES::-1} # remove the last character ","
        fi
        if [[ -z "$SOCKET_BIND_NODE" ]]; then
            echo "Not specified socket bind node, by default using all nodes $DEFAULT_NODES"
            SOCKET_BIND_NODE=$DEFAULT_NODES
        fi
        if ${EXCLUDE_IRQ_CORES:-false}; then
            function get_network_device_by_ip() {
                node_ip=$1
                ALL_NETWORK_DEVICES=($(ls /sys/class/net))
                for dev in "${ALL_NETWORK_DEVICES[@]}"
                do
                    output=$(ifconfig $dev)
                    if [[ "$output" =~ "$node_ip" ]]; then
                        rtn_net_dev=$dev # device found by node ip
                        break
                    fi
                done
                echo "$rtn_net_dev"
            }
            NET_DEV=$(get_network_device_by_ip $NODE_IP)
            file1=/tmp/node_cores
            file2=/tmp/irq_cores
            irq_cores=()
            for i in $(cat /proc/interrupts |grep "$NET_DEV" |awk -F ':' '{print $1}')
            do 
                irq_cores+=($(cat /proc/irq/$i/smp_affinity_list))
            done
            echo "irq_cores: ${irq_cores[@]}"
            echo "${irq_cores[@]}" |tr ' ' '\n' > $file2

            nodes=($(echo $SOCKET_BIND_NODE |tr '_\|,' ' ')) #split by _ or ,
            for node in ${nodes[@]}
            do
                node_cores+=($(grep ",$node" /tmp/cpu_numa_map | awk -F ',' '{print $1}'))
            done
            echo "node_cores: ${node_cores[@]}"
            echo "${node_cores[@]}" |tr ' ' '\n' >  $file1
            
            # file1 - file2
            app_cores=$(sort -m <(sort $file1 | uniq) <(sort $file2 | uniq) <(sort $file2 | uniq) | uniq -u |sort -n|tr '\n' ',')
            if [[ "${app_cores}" =~ ^.*,$ ]]; then
                app_cores=${app_cores::-1} # remove the last character ","
            fi
            echo "app_cores: $app_cores"
            NUMACTL_OPTIONS="numactl --physcpubind=$app_cores --localalloc"
            echo "Run on multi node, socket bind enabled, bind on cores exclude interrupt cores"
        else
            NUMACTL_OPTIONS="numactl --cpunodebind=$SOCKET_BIND_NODE --localalloc"
            echo "Run on multi node, socket bind enabled, bind on nodes: $SOCKET_BIND_NODE"
        fi
    else
        echo "Run on multi node, socket bind disabled, skip to bind"
    fi
fi
echo "NUMACTL_OPTIONS: $NUMACTL_OPTIONS"
### end numactl bind core logic

echo "===Stage 1: Build schema started==="
start=$(date +%s)
./hammerdbcli auto ${TPCC_TCL_SCRIPT_PATH}/build_schema.tcl | tee /build_schema_${DB_TYPE}_tcl.log
end=$(date +%s)
echo "===Stage 1: Build schema finished spent $(( end - start )) seconds"

echo "===Stage 2: Run timer started"
$NUMACTL_OPTIONS ./hammerdbcli auto ${TPCC_TCL_SCRIPT_PATH}/run_timer.tcl | tee /run_timer_${DB_TYPE}_tcl.log
echo "===Stage 2: Run timer finished"

exit

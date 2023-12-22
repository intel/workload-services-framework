#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# shellcheck source=/dev/null
source ./common.sh

function usage {
    cat <<EOF

        config.sh is used to configure environment for HAProxy workload testing.

        Usage:
            ./config.sh [--mode native|qatsw|qathw] [--haproxy-cores <HAProxy core list>] [--haproxy-port <HAProxy port>] [--haproxy-nbthread <HAProxy nbthread number>] 
                        [--haproxy-thread-group <HAProxy thread groups>] [--haproxy-http-keep-alive true|false] [--nginx-cores <Nginx core list>] [--nginx-workers <Nginx workers>]
                        [--nginx-port <Nginx port>] [--bind-irq-devices <NIC devices>] [-y] [--help|-h]

        Example:
            ./config.sh --mode native -y
            ./config.sh --mode qatsw --haproxy-cores 65-68,193-196 --haproxy-nbthread 8 --nginx-cores 96-103,224-231 --nginx-workers 16 --haproxy-http-keep-alive true --bind-irq-devices ens801f0 -y
            ./config.sh --mode qathw --haproxy-cores 65-72,193-200 --haproxy-nbthread 16 --nginx-cores 96-103,224-231 --nginx-workers 16 --haproxy-http-keep-alive false --bind-irq-devices ens801f0 -y

        Parameters:
            --mode native|qatsw|qathw: [Optional] Specify configuration mode, value can be native, qatsw or qathw. Default is native.
            --haproxy-cores <HAProxy core list>: [Optional] Specify HAProxy core list, for example: 65-68,193-196. 
                                                 Default value will be generated according to testing environment, it's the second physical and logical core, for example: "1-1,129-129".
            --haproxy-port <HAProxy port>: [Optional] Specify HAProxy port. Default is 9000.
            --haproxy-nbthread <HAProxy nbthread number>: [Optional] Specify HAProxy nbthread number, in general, this value should be the core numbers of HAProxy core list. Default is 2.
            --haproxy-thread-group <HAProxy thread groups>: [Optional] Specify HAProxy thread groups. Default is 2.
            --haproxy-http-keep-alive true|false: [Optional] Specify HAProxy http keep alive value, value can be true or false. Default is true.
                                                  Set value to false for handshake(RPS) case and true for throughput case.
            --nginx-cores <Nginx core list>: [Optional] Specify Nginx core list, for example: 96-103,224-231. 
                                             Default value will be generated according to testing environment, it's the first physical and logical core, for example: "0-0,128-128".
            --nginx-workers <Nginx workers>: [Optional] Specify Nginx workers, in general, this value should be the core numbers of Nginx core list. Default is 2.
            --nginx-port <Nginx port>: [Optional] Specify Nginx port. Default is 9080.
            --bind-irq-devices <NIC devices>: [Optional] Specify NIC devices which IRQ will be bound on HAProxy cores for these NIC devices, for example "ens817f0" or "ens817f0,ens817f1". Default is "", will not bind NIC IRQ.
            --help|-h: [Optional] Show help messages.

EOF
}

function prepare_config_file_common() {
    # HAProxy
    cp "$haproxy_config_file" "$haproxy_config_dep_file"
    sed -i "s/nbthread.*/nbthread ${haproxy_nbthread}/" "$haproxy_config_dep_file"
    sed -i "s/thread-groups.*/thread-groups ${haproxy_thread_group}/" "$haproxy_config_dep_file"
    sed -i "s/bind :9000/bind :${haproxy_port}/" "$haproxy_config_dep_file"
    sed -i "s|haproxy.pid|$CONFIGS_DEP_DIR/haproxy.pid|" "$haproxy_config_dep_file"
    sed -i "s|/haproxy-tls-combined.pem|$HAPROXY_KEYS_DIR/haproxy-tls-combined.pem|" "$haproxy_config_dep_file"
    [[ "$haproxy_http_keep_alive" = "$KEEP_ALIVE_FALSE" ]] && sed -i "0,/option http.*/s//option httpclose/" "$haproxy_config_dep_file"
    # Nginx
    cp "$nginx_config_file" "$nginx_config_dep_file"
    sed -i "s/worker_processes.*/worker_processes ${nginx_workers};/" "$nginx_config_dep_file"
    sed -i "s|root /var/www/html;|root ${NGINX_WEB_ROOT};|" "$nginx_config_dep_file"
    cp "$CONFIGS_DIR/mime.types" "$CONFIGS_DEP_DIR/mime.types"
}

function prepare_config_file_qat() {
    sed -i "/# QAT_ENGINE_CONFIG_ANCHOR/a\        ssl-mode-async" "$haproxy_config_dep_file"
    sed -i "/# QAT_ENGINE_CONFIG_ANCHOR/a\        ssl-engine qatengine algo RSA,EC,DSA,DH,PKEY,PKEY_CRYPTO,PKEY_ASN1" "$haproxy_config_dep_file"
}

function config_qatengine_for_qatsw() {
    info "Configuring QAT Engine for QATSW..."
    (sudo rm -rf "$BASE_DIR/QAT_Engine" && cp -r "$BASE_DIR/QAT_Engine_ori" "$BASE_DIR/QAT_Engine" && cd "$BASE_DIR/QAT_Engine" && \
    sudo ./autogen.sh > /dev/null 2>&1 && \
    sudo ./configure --enable-qat_sw --disable-qat_hw > /dev/null && \
    sudo make -j install > /dev/null) || \
    error "Failed to enable QAT Engine for QATSW."
}

function config_qatengine_for_qathw() {
    info "Configuring QAT Engine for QATHW..."
    (sudo rm -rf "$BASE_DIR/QAT_Engine" && cp -r "$BASE_DIR/QAT_Engine_ori" "$BASE_DIR/QAT_Engine" && cd "$BASE_DIR/QAT_Engine" && \
    sudo ./autogen.sh > /dev/null 2>&1 && \
    sudo ./configure --with-qat_hw_dir="$QAT_OOT_DRIVER_DIR" --enable-qat_hw_contig_mem --enable-qat_hw_multi_thread --disable-qat_sw > /dev/null && \
    sudo make -j install > /dev/null) || \
    error "Failed to enable QAT Engine for QATHW."
}

function startup_services() {
    info "Starting Nginx service..."
    pgrep -f "nginx -c" > /dev/null && (sudo pkill nginx || error "Failed to stop Nginx service.")
    taskset -c "$nginx_cores" nginx -c "$nginx_config_dep_file" || error "Failed to startup Nginx service."

    info "Starting HAProxy service..."
    pgrep -f "haproxy -D -f" > /dev/null && (sudo pkill haproxy || error "Failed to stop HAProxy service.")
    sleep 5
    # Delete socket file if exists
    sudo rm -f /tmp/haproxy.sock
    sudo taskset -c "$haproxy_cores" haproxy -D -f "$haproxy_config_dep_file" || error "Failed to startup HAProxy service."
}

function get_first_logic_core_index() {
    logic_core_index=$(lscpu | grep "NUMA node0 CPU(s):" | awk '{print $4}')
    logic_core_index=${logic_core_index#*,}
    logic_core_index=${logic_core_index%-*}
}

function config_native() {
    info "Configuring native mode..."
    prepare_config_file_common
    startup_services
    bind_irq
}

function config_qatsw() {
    info "Configuring qatsw mode..."
    prepare_config_file_common
    prepare_config_file_qat
    config_qatengine_for_qatsw
    startup_services
    bind_irq
}

function config_qathw() {
    info "Configuring qathw mode..."
    prepare_config_file_common
    prepare_config_file_qat
    config_qatengine_for_qathw
    startup_services
    bind_irq
}

function check_intree_driver() {
    [[ ! -d "/usr/include/qat" ]] || \
    error "Directory /usr/include/qat exists, QAT intree driver may be installed, please uninstall it and try again."
}

function bind_irq() {
    [[ ! "$bind_irq_devices" = "" ]] || return
    # Disable irqbalance
    sudo systemctl stop irqbalance || error "Failed to stop irqbalance service."
    core_array=()
    IFS=',' read -ra cores_array_tmp <<< "$haproxy_cores"
    for var in "${cores_array_tmp[@]}"; do
        if [[ $var == *-* ]]; then
            IFS='-' read -ra cores_array_tmp_sub <<< "$var"
            for (( i=cores_array_tmp_sub[0]; i<=cores_array_tmp_sub[1]; i=i+1 )); do
                len=${#core_array[*]}
                core_array[$len]=$i
            done
        else
            len=${#core_array[*]}
            core_array[$len]="$var"
        fi
    done
    IFS=',' read -ra device_array <<< "$bind_irq_devices"
    for device in "${device_array[@]}"; do
        info "Binding IRQ for NIC device: $device, cores: $haproxy_cores"
        core_list_len="${#core_array[@]}"
        while IFS='' read -r line; do irq_list+=("$line"); done < <(grep "$device" < /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')
        irq_list_len=${#irq_list[@]}
        for(( i=0; i<irq_list_len; i=i+1 )); do
            core_idx=$((i % core_list_len))
            core=${core_array[$core_idx]}
            echo "$core" | sudo tee /proc/irq/"${irq_list[$i]}"/smp_affinity_list > /dev/null
        done
    done
}

function save_configuration_parameters() {
    {
        echo "Mode: $mode"
        echo "HAProxy cores: $haproxy_cores"
        echo "HAProxy port: $haproxy_port"
        echo "HAProxy nbthread: $haproxy_nbthread"
        echo "HAProxy thread group: $haproxy_thread_group"
        echo "HAProxy http keep alive: $haproxy_http_keep_alive"
        echo "Nginx cores: $nginx_cores"
        echo "Nginx workers: $nginx_workers"
        echo "Nginx port: $nginx_port"
        echo "Bind irq devices: $bind_irq_devices"
    } > "$CONFIG_PARAMS_FILE"
}

function check_conditions() {
    info "Checking environment and parameters..."
    check_os
    check_intree_driver
}

##############################################################

# Mode
MODE_NATIVE="native"
MODE_QATSW="qatsw"
MODE_QATHW="qathw"
mode=$MODE_NATIVE

# Keep alive values
KEEP_ALIVE_TRUE="true"
KEEP_ALIVE_FALSE="false"

# Get first logic core
logic_core_index=""
get_first_logic_core_index

# Parameters
haproxy_cores="1,$(( logic_core_index+1 ))"
haproxy_port=9000
haproxy_nbthread=2
haproxy_thread_group=2
haproxy_http_keep_alive=$KEEP_ALIVE_TRUE
nginx_cores="0,${logic_core_index}"
nginx_workers=2
nginx_port=9080
bind_irq_devices=""

# Configuration files
haproxy_config_file="$CONFIGS_DIR/haproxy.cfg"
haproxy_config_dep_file="$CONFIGS_DEP_DIR/haproxy.cfg"
nginx_config_file="$CONFIGS_DIR/nginx.conf"
nginx_config_dep_file="$CONFIGS_DEP_DIR/nginx.conf"

# Parse input arguments
UNKNOWN_ARGS=""
while [[ "$1" != "" ]]
do
    arg=$1
    case $arg in
        --mode)
            shift
            check_not_empty "$arg" "$1"
            modes=("$MODE_NATIVE" "$MODE_QATSW" "$MODE_QATHW")
            check_value_exist "$arg" "$1" "${modes[@]}"
            mode=$1
            ;;
        --haproxy-cores)
            shift
            check_not_empty "$arg" "$1"
            haproxy_cores=$1
            ;;
        --haproxy-port)
            shift
            check_not_empty "$arg" "$1"
            haproxy_port=$1
            ;;
        --haproxy-nbthread)
            shift
            check_not_empty "$arg" "$1"
            haproxy_nbthread=$1
            ;;
        --haproxy-thread-group)
            shift
            check_not_empty "$arg" "$1"
            haproxy_thread_group=$1
            ;;
        --haproxy-http-keep-alive)
            shift
            check_not_empty "$arg" "$1"
            keepalives=("$KEEP_ALIVE_TRUE" "$KEEP_ALIVE_FALSE")
            check_value_exist "$arg" "$1" "${keepalives[@]}"
            haproxy_http_keep_alive=$1
            ;;
        --nginx-cores)
            shift
            check_not_empty "$arg" "$1"
            nginx_cores=$1
            ;;
        --nginx-workers)
            shift
            check_not_empty "$arg" "$1"
            nginx_workers=$1
            ;;
        --nginx-port)
            shift
            check_not_empty "$arg" "$1"
            nginx_port=$1
            ;;
        --bind-irq-devices)
            shift
            check_not_empty "$arg" "$1"
            check_nic_interfaces "$arg" "$1"
            bind_irq_devices=$1
            ;;
        -y)
            skip_confirm="true" && export skip_confirm
            ;;
        --help|-h)
            usage && exit
            ;;
        *) UNKNOWN_ARGS="$UNKNOWN_ARGS $arg"
            ;;
    esac
    shift
done
[[ -z "$UNKNOWN_ARGS" ]] || error "Unknown arguments:$UNKNOWN_ARGS"

check_conditions
confirm "Will configure environment with $mode mode"

[ -d "$CONFIGS_DEP_DIR" ] && sudo rm -rf "$CONFIGS_DEP_DIR"
mkdir "$CONFIGS_DEP_DIR"

if [[ "$mode" = "$MODE_NATIVE" ]]; then
    config_native
elif [[ "$mode" = "$MODE_QATSW" ]]; then
    config_qatsw
elif [[ "$mode" = "$MODE_QATHW" ]]; then
    config_qathw
else
    error "Unknown mode type: $mode"
fi

save_configuration_parameters

info "Succeed to configure environment, below are configuration parameters,"
cat "$CONFIG_PARAMS_FILE"

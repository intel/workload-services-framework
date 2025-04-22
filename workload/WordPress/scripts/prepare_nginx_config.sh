#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

echo "ASYNC MODE: $ASYNC "
echo "NGINX_WORKER_PROCESSES: $NGINX_WORKER_PROCESSES"
echo "CURVE: $CURVE"
echo "PROTOCOL: $PROTOCOL"
echo "CIPHER: $CIPHER"

NGINXCONF=${NGINXCONF:-/usr/local/share/nginx/conf/nginx.conf}
NGINX_NUMA_OPTIONS_THIS_INSTANCE=""

# CERTKEY=/private/key_rsa2048.key
echo "CERT: $CERT"
echo "CERTKEY: $CERTKEY"

mkdir certs
mkdir private

if [[ $CERT == "secp384r1" ]]; then
    openssl ecparam -genkey -out private/key_secp384r1.pem -name secp384r1
    openssl req -x509 -new -key private/key_secp384r1.pem -out certs/cert_secp384r1.pem -batch
    CERT=/certs/cert_secp384r1.pem
    CERTKEY=/private/key_secp384r1.pem
elif [[ $CERT == "prime256v1" ]];then
    openssl ecparam -genkey -out private/key_prime256v1.pem -name prime256v1
    openssl req -x509 -new -key private/key_prime256v1.pem -out certs/cert_prime256v1.pem -batch
    CERT=/certs/cert_prime256v1.pem
    CERTKEY=/private/key_prime256v1.pem
elif [[ $CERT == "rsa3072" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:3072 -keyout private/key_rsa3072.key -out certs/cert_rsa3072.crt -batch #RSA Cert
    CERT=/certs/cert_rsa3072.crt
    CERTKEY=/private/key_rsa3072.key
elif [[ $CERT == "rsa4096" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout private/key_rsa4096.key -out certs/cert_rsa4096.crt -batch #RSA Cert
    CERT=/certs/cert_rsa4096.crt
    CERTKEY=/private/key_rsa4096.key
else
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout private/key_rsa2048.key -out certs/cert_rsa2048.crt -batch #RSA Cert
    CERT=/certs/cert_rsa2048.crt
    CERTKEY=/private/key_rsa2048.key
fi

echo "CERT: $CERT"
echo "CERTKEY: $CERTKEY"

echo "NGINXCONF:$NGINXCONF"

if [[ $PROTOCOL == "TLSv1.2" ]]; then
    sed -i "s|ssl_ciphers          ECDHE-RSA-AES128-GCM-SHA256|ssl_ciphers          $CIPHER|" $NGINXCONF
else
    sed -i "s|ssl_protocols        TLSv1.2|ssl_protocols        $PROTOCOL|" $NGINXCONF
    sed -i "s|ssl_ciphers|#ssl_ciphers|" $NGINXCONF
    sed -i "s|#ssl_conf_command Ciphersuites TLS_AES_128_GCM_SHA256|ssl_conf_command Ciphersuites $CIPHER|" $NGINXCONF

fi

sed -i "s|ssl_ecdh_curve       X25519|ssl_ecdh_curve       $CURVE|" $NGINXCONF
sed -i "s|ssl_certificate      /certs/nginx-selfsigned.crt|ssl_certificate      $CERT|" $NGINXCONF
sed -i "s|ssl_certificate_key  /private/nginx-selfsigned.key|ssl_certificate_key  $CERTKEY|" $NGINXCONF

# Disable QAT, delete QAT related configures
if [[ $ASYNC == "off" ]]; then
    sed -i "/load_module modules\/ngx_ssl_engine_qat_module.so;/d" $NGINXCONF
    sed -i "/qat_engine {/,/}/d" $NGINXCONF
    sed -i "/ssl_engine {/,/}/d" $NGINXCONF
    sed -i "/ssl_asynch/d" $NGINXCONF
fi

function reset_nginx_worker_processes() {
    numa_options=$1 # NGINX_NUMA_OPTIONS
    # Replace back replace holder ? to space for arguments
    numa_options=${numa_options//"?"/" "}
    numa_options=${numa_options//"!"/","}
    count=$2    # INSTANCE_COUNT
    nginx_worker_processes_given=$3 # NGINX_WORKER_PROCESSES
    nginx_worker_processes_real=0
    core_num=0
    if [ "$nginx_worker_processes_given" == "auto" ]; then
        if [[ "${numa_options}" == *"-C "* ]]; then
            local cpuslist_str=$(echo "${numa_options}" | awk -F '-C ' '{print $2}' | awk '{print $1}')
            local cpuslist_half=$(echo $cpuslist_str | awk -F ',' '{print $1}')
            local start=$(echo "$cpuslist_half" | cut -d'-' -f1)
            local end=$(echo "$cpuslist_half" | cut -d'-' -f2)
            if [ "$count" -gt "$((end - start + 1))" ]; then
                nginx_worker_processes_real=1
            else
                local cpu_num_half=$(( ($end - $start + 1) / count ))
                nginx_worker_processes_real=$((2 * cpu_num_half))
            fi
        fi
        if [[ "${numa_options}" == "--interleave=all" ]]; then
            core_num=$(nproc)
            nginx_worker_processes_real=$((core_num / count))
        fi
    else
        nginx_worker_processes_real=$nginx_worker_processes_given
    fi

    echo "Set worker_processes = $nginx_worker_processes_real"
    sed -i "s|worker_processes auto|worker_processes $nginx_worker_processes_real|" $NGINXCONF
}

function get_all_cpu_pinning() {
    sockets_num=$(lscpu | grep "Socket(s):" | sed "s/.* //g")

    for cpu in $(ls -d /sys/devices/system/cpu/cpu[0-9]* | sort -t u -k 3 -n); do
        socket_id=$(cat $cpu/topology/physical_package_id)
        tmp_name=cpusets_socket${socket_id}
        declare ${tmp_name}+=$(cat $cpu/topology/thread_siblings_list)" "
    done
    cpu_pinning_s=()
    count_per_socket=$((INSTANCE_COUNT / sockets_num))

    for ((socket_id = 0; socket_id < ${sockets_num}; socket_id++)); do
        tmp_name=cpusets_socket${socket_id}
        all_cpus=($(echo ${!tmp_name} | tr ' ' '\n' | cat -n | sort -uk2 | sort -n | cut -f2- | tr '\n' ' '))
        if [[ ${socket_id} -eq $((${sockets_num} - 1)) ]]; then
            count_per_socket=$(($count_per_socket + $INSTANCE_COUNT % $sockets_num))
        fi
        cpu_per_instance=$((${#all_cpus[@]} / $count_per_socket))
        start=0
        for ((i = 1; i <= $count_per_socket; i++)); do
            if [[ ${i} -eq $count_per_socket ]]; then
                array=("${all_cpus[@]:${start}}")
            else
                array=("${all_cpus[@]:${start}:${cpu_per_instance}}")
            fi
            start=$((start + cpu_per_instance))
            cpuset_cpus_s=$(printf ",%s" "${array[@]}")
            cpuset_cpus_s=${cpuset_cpus_s:1}

            numa_run_s="-C "${cpuset_cpus_s}" --localalloc"
            cpu_pinning_s+=("$numa_run_s")
        done
    done
}

function split_cpulist() {
    local cpulist=$1
    local count=$2
    local start=$(echo "$cpulist" | cut -d'-' -f1)
    local end=$(echo "$cpulist" | cut -d'-' -f2)
    if [ "$count" -gt "$((end - start + 1))" ]; then
        for ((i = 0; i < $count; i++)); do
            partitions+=("$cpulist")
        done
    else
        local step=$(( ($end - $start + 1) / count ))
        local partitions=()
        for ((i = 0; i < $count; i++)); do
                range_start=$(( $start + $i * $step ))
                range_end=$(( $range_start + $step - 1))
                partitions+=("$range_start-$range_end")
        done
    fi
    echo "${partitions[@]}"
}

function get_partial_cpu_pinning() {
    numa_options=$1 # MARIADB_NUMA_OPTIONS
    count=$2
    cpuslist_str=$(echo "${numa_options}" | awk -F '-C ' '{print $2}' | awk '{print $1}')
    total_cpu_list=$(echo "$cpuslist_str" | awk -F ',' '{print NF}')
    IFS=',' read -r -a cpu_list_array <<< "$cpuslist_str"
    splist=()
    for ((i = 0; i < $total_cpu_list; i++)); do
        splited_cpuslist=($(split_cpulist "${cpu_list_array[$i]}" $count))
        for ((j = 0; j < $count; j++)); do
           splist[$j]+="${splited_cpuslist[$j]}"
           if (( i < total_cpu_list - 1 )); then
                splist[$j]+=","
           fi
        done
    done
    local merged_cpuslist=()
    for ((j = 0; j < $count; j++)); do
        merged_cpuslist+=("${splist[j]}")
    done
    echo "${merged_cpuslist[@]}"
}

function numa_nginx() {
    if [[ -n "$VCPUS_PER_INSTANCE" && $SUTINFO_CSP == "static" ]]; then
        IFS='_' read -r -a instance_cpus_array <<< "$ALL_INSTANCE_CPU_STR"
        NGINX_NUMA_OPTIONS_THIS_INSTANCE="-C ${instance_cpus_array[$BENCHMARK_ID]} --localalloc"
    elif [[ $NGINX_NUMA_OPTIONS == "--interleave=all" ]];then
        if [[ $INSTANCE_COUNT -gt 1 ]]; then
            get_all_cpu_pinning
            NGINX_NUMA_OPTIONS_THIS_INSTANCE=${cpu_pinning_s[$BENCHMARK_ID]}
        elif [[ $INSTANCE_COUNT -eq 1 ]]; then
            NGINX_NUMA_OPTIONS_THIS_INSTANCE=$NGINX_NUMA_OPTIONS
        fi
    else
        # Replace back replace holder ? to space for arguments
        NGINX_NUMA_OPTIONS=${NGINX_NUMA_OPTIONS//"?"/" "}
        NGINX_NUMA_OPTIONS=${NGINX_NUMA_OPTIONS//"!"/","}
        if [[ $INSTANCE_COUNT -gt 1 ]]; then
            partial_cpu_pinning_s=($(get_partial_cpu_pinning "$NGINX_NUMA_OPTIONS" $INSTANCE_COUNT))
            NGINX_NUMA_OPTIONS_THIS_INSTANCE="-C ${partial_cpu_pinning_s[$BENCHMARK_ID]} --localalloc"
        elif [[ $INSTANCE_COUNT -eq 1 ]]; then
            NGINX_NUMA_OPTIONS_THIS_INSTANCE=$NGINX_NUMA_OPTIONS
        fi
    fi
    echo "NGINX_NUMA_OPTIONS_THIS_INSTANCE: ${NGINX_NUMA_OPTIONS_THIS_INSTANCE}"
    numactl $NGINX_NUMA_OPTIONS_THIS_INSTANCE nginx -c ${NGINXCONF}
}

reset_nginx_worker_processes "$NGINX_NUMA_OPTIONS" $INSTANCE_COUNT $NGINX_WORKER_PROCESSES
cp ${NGINXCONF} source.template
sed -i 's|WORDPRESS_HOST|'$WORDPRESS_HOST'|g' ${NGINXCONF}
sed -i 's|WORDPRESS_PORT|'$WORDPRESS_PORT'|g' ${NGINXCONF}
if [[ $HTTPMODE == "http" ]];then
    sed -i "s|listen   8080|listen $NGINX_PORT|g" ${NGINXCONF}
else
    sed -i "s|listen       8443|listen $NGINX_PORT|g" ${NGINXCONF}
fi

numa_nginx

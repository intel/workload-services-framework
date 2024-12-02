#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORKLOAD=${WORKLOAD:-cdn_nginx_original}
NODE=${NODE:-3n}
HTTPMODE=${HTTPMODE:-https}
SYNC=${SYNC:-sync}
GATED=${GATED:-""}
QAT_RESOURCE_NUM=${QAT_RESOURCE_NUM:-16}
PROTOCOL=${PROTOCOL:-TLSv1.2}
CERT=${CERT:-rsa2048}
CIPHER=${CIPHER:-AES128-GCM-SHA256}
CURVE=${CURVE:-auto}
NICIP_W2=${NICIP_W2:-192.168.2.201}
SINGLE_SOCKET=${SINGLE_SOCKET:-"false"}
CPU_AFFI=${CPU_AFFI:-"false"}
NGINX_WORKERS=${NGINX_WORKERS:-4}
NGINX_CPU_LISTS=${NGINX_CPU_LISTS:-""}

NGINX_EXE="/home/cdn/sbin/nginx"

function parse_input_cpu() {
    input_cpu=${1// /}
    IFS_BAK="$IFS"
    IFS="_"
    input_cpu=($input_cpu)
    input_cpu_len=${#input_cpu[@]}

    parsed_cpu=""
    parsed_cpu_idx=0
    for(( i = 0; i < input_cpu_len; i ++ ))
    do
        IFS="-"
        current_group=(${input_cpu[$i]})
        if [[ ${#current_group[@]} == 1 ]]; then
            parsed_cpu[$parsed_cpu_idx]=$current_group
            parsed_cpu_idx=$(( $parsed_cpu_idx + 1 ))
        elif [[ ${#current_group[@]} == 2 ]]; then
            current_group_start=${current_group[0]}
            current_group_end=${current_group[1]}
            current_group_cpu_num=$(( $current_group_end-$current_group_start+1 ))
            for (( j = 0; j < current_group_cpu_num; j ++ ))
            do
                parsed_cpu[$parsed_cpu_idx]=$(( $current_group_start+$j ))
                parsed_cpu_idx=$(( $parsed_cpu_idx + 1 ))
            done
        fi
    done

    IFS="$IFS_BAK"
    echo ${parsed_cpu[@]}
}

## Select NGINX configuration file
if [[ "$HTTPMODE" == "http" ]]; then
  NGINXCONF=${NGINXCONF:-/home/cdn/etc/nginx/nginx-http.conf}
elif [[ "$HTTPMODE" == "https" ]]; then
  if [[ "$SYNC" == "sync" ]]; then
    NGINXCONF=${NGINXCONF:-/home/cdn/etc/nginx/nginx-https.conf}
  elif [[ "$SYNC" == "async" ]]; then
    NGINXCONF=${NGINXCONF:-/home/cdn/etc/nginx/nginx-async-on.conf}
  fi
fi

## Reduce to 2 cache disks, single socket test
if [[ "$SINGLE_SOCKET" == "true" ]]; then
  sed -i 's/25% "nginx-cache0";/50% "nginx-cache0";/' $NGINXCONF
  sed -i 's/25% "nginx-cache1";/50% "nginx-cache1";/' $NGINXCONF
  sed -i '/cache2\|cache3/d' $NGINXCONF 
fi

ulimit -a

## Set NGINX worker number to QAT instance number in qathw cases
if [[ "$WORKLOAD" == "cdn_nginx_qathw" ]]; then
  NGINX_WORKERS=$QAT_RESOURCE_NUM
fi
sed -i "s|worker_processes auto;|worker_processes $NGINX_WORKERS;|" $NGINXCONF


## Configure 100G NIC IP of origin server, only 3-node cases
if [ "$GATED" != "gated" ];then
  if [ "$NODE" == "3n" ];then
    sed -i "s|server originnginxurl:18080;|server $NICIP_W2:18080;|" $NGINXCONF
  fi
fi


mkdir -p certs
mkdir -p keys
# cert and key
if [[ "$CERT" == "secp384r1" ]]; then
    openssl ecparam -genkey -out keys/key_secp384r1.pem -name secp384r1 
    openssl req -x509 -new -key keys/key_secp384r1.pem -out certs/cert_secp384r1.pem -batch
    CERT=/certs/cert_secp384r1.pem
    CERTKEY=/keys/key_secp384r1.pem
elif [[ "$CERT" == "prime256v1" ]];then
    openssl ecparam -genkey -out keys/key_prime256v1.pem -name prime256v1
    openssl req -x509 -new -key keys/key_prime256v1.pem -out certs/cert_prime256v1.pem -batch
    CERT=/certs/cert_prime256v1.pem
    CERTKEY=/keys/key_prime256v1.pem
elif [[ "$CERT" == "rsa2048" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout keys/key_rsa2048.key -out certs/cert_rsa2048.crt -batch #RSA Cert
    CERT=/certs/cert_rsa2048.crt
    CERTKEY=/keys/key_rsa2048.key
elif [[ "$CERT" == "rsa3072" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:3072 -keyout keys/key_rsa3072.key -out certs/cert_rsa3072.crt -batch #RSA Cert
    CERT=/certs/cert_rsa3072.crt
    CERTKEY=/keys/key_rsa3072.key
elif [[ "$CERT" == "rsa4096" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout keys/key_rsa4096.key -out certs/cert_rsa4096.crt -batch #RSA Cert
    CERT=/certs/cert_rsa4096.crt
    CERTKEY=/keys/key_rsa4096.key
elif [[ "$CERT" == "ecdhersa" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout keys/key_rsa2048.key -batch #RSA Key
    openssl req -x509 -new -key keys/key_rsa2048.key -out certs/cert_ecrsa2048.pem -batch 
    CERT=/certs/cert_ecrsa2048.pem
    CERTKEY=/keys/key_rsa2048.key
elif [[ "$CERT" == "ecdheecdsa" ]];then
    openssl ecparam -genkey -out keys/key_ecdsa256.pem -name prime256v1 #ecdsa Cert
    openssl req -x509 -new -key keys/key_ecdsa256.pem -out certs/cert_ecdsa256.pem -batch #finalize ecdsa Cert
    CERT=/certs/cert_ecdsa256.pem
    CERTKEY=/keys/key_ecdsa256.pem
else
    CERT=/certs/nginx-selfsigned.crt
    CERTKEY=/keys/nginx-selfsigned.key
fi
echo "CERT: $CERT"
echo "CERTKEY: $CERTKEY"

if [[ "$HTTPMODE" == "https" ]]; then
  if [[ "$PROTOCOL" == "TLSv1.2" ]]; then
    sed -i "s|ssl_ciphers AES128-SHA:AES256-SHA|ssl_ciphers $CIPHER|" $NGINXCONF
  elif [[ "$PROTOCOL" == "TLSv1.3" ]]; then
    sed -i "s|ssl_protocols TLSv1.2|ssl_protocols $PROTOCOL|" $NGINXCONF
    sed -i "s|ssl_ciphers AES128-SHA:AES256-SHA|ssl_conf_command Ciphersuites $CIPHER|" $NGINXCONF
  else
    sed -i "s|ssl_protocols TLSv1.2|ssl_protocols $PROTOCOL|" $NGINXCONF
    sed -i "s|ssl_ciphers|#ssl_ciphers|" $NGINXCONF
  fi
  sed -i "s|ssl_ecdh_curve auto|ssl_ecdh_curve $CURVE|" $NGINXCONF
  sed -i "s|ssl_certificate /home/cdn/certs/server.cert.pem|ssl_certificate $CERT|" $NGINXCONF
  sed -i "s|ssl_certificate_key /home/cdn/certs/server.key.pem|ssl_certificate_key $CERTKEY|" $NGINXCONF
fi


echo "NGINX_WORKERS=$NGINX_WORKERS"
echo "NGINX_EXE=$NGINX_EXE"
echo "NGINXCONF=$NGINXCONF"

if [ "$CPU_AFFI" == "true" ]; then
  ## If core list not defined, bind NGINX to first 'NGINX_WORKERS' cores
  if [ "$NGINX_CPU_LISTS" == "" ]; then
    NGINX_LAST_CORE=$(( $NGINX_WORKERS - 1 ))
    NGINX_CPU_LISTS="0-$NGINX_LAST_CORE"
  fi

  echo Bind NGINX to NGINX_CPU_LISTS: $NGINX_CPU_LISTS
  input_cpu=($(parse_input_cpu "${NGINX_CPU_LISTS[@]}"))
  input_cpu_len=${#input_cpu[@]}
  
  taskset -c ${NGINX_CPU_LISTS/_/,} ${NGINX_EXE} -c ${NGINXCONF} &
  sleep 10

  # Bind each Nginx worker to dedicate core
  pids=($(pgrep --full "nginx: worker process"))
  index=0
  for pid in ${pids[@]}; do
    taskset -pc ${input_cpu[index]} $pid
    index=$((index+1))
    if [[ "$index" -ge "$input_cpu_len" ]]; then
      index=0
    fi
  done
  sleep infinity
else
  echo Run NGINX without core bind.
  ${NGINX_EXE} -c ${NGINXCONF}
fi


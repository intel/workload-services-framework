#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-nginx_qatsw}
PROTOCOL=${PROTOCOL:-TLSv1.3}
QATACCL=${QATACCL:-async}
MODE=${MODE:-https}
PORT=${PORT:-443}
CERT=${CERT:-rsa2048}
CIPHER=${CIPHER:-AES128-GCM-SHA256}
NGINX_CPU_LISTS=${NGINX_CPU_LISTS:-0}
CURVE=${CURVE:-auto}

echo POD_OWN_IP_ADDRESS:$POD_OWN_IP_ADDRESS
echo NODE_OWN_IP_ADDRESS:$NODE_OWN_IP_ADDRESS
echo NGINX_CPU_LISTS:${NGINX_CPU_LISTS}

#TEST_IN_VM=`lscpu | grep Hypervisor`


if [ $POD_OWN_IP_ADDRESS ]; then
  echo $POD_OWN_IP_ADDRESS > /var/www/html/nginxserverpodip
fi
if [ $NODE_OWN_IP_ADDRESS ]; then
  echo $NODE_OWN_IP_ADDRESS > /var/www/html/nginxservernodeip
fi

echo "WORKLOAD: $WORKLOAD"
echo "QAT ACCL MODE: $QATACCL"
echo "MODE: $MODE"
echo "PORT: $PORT"
echo "PROTOCOL: $PROTOCOL"
echo "CERT:${CERT}"
echo "CIPHER: $CIPHER"
echo "CURVE: $CURVE"
echo "NODE: $NODE"

whole_system_cores=`nproc`
echo system cores $whole_system_cores
if [[ $MAX_CORE_WORKER_CLIENT == "true" ]]; then
    NGINX_WORKERS=$whole_system_cores
else
    NGINX_WORKERS=${NGINX_WORKERS:-4}
fi
echo "NGINX_WORKERS:${NGINX_WORKERS}"

if [ $NGINX_WORKERS -gt $whole_system_cores ]; then
  echo warning, system cores not enough for nginx worker $NGINX_WORKERS, use $whole_system_cores
  NGINX_WORKERS=$whole_system_cores
fi

if [ $NGINX_CPU_LISTS == 0 ]; then
  NGINX_LAST_CORE=$(( $NGINX_WORKERS - 1 ))
  NGINX_CPU_LISTS=0-$NGINX_LAST_CORE
fi

ulimit -a

# workaround for aws m6i.16xlarge 64c VM only has 8 rx/tx combined queues and 8 IRQs
# if [[ $(systemd-detect-virt) == "docker" ]]; then
#   echo test in local bare metal
# else
#   echo test in cloud
#   if [ $NGINX_WORKERS ] && [ $NGINX_WORKERS -gt 32 ] && [ $NODE_OWN_IP_ADDRESS ]; then
#     for dir in /sys/class/net/*/     # list directories
#     do
#       dir=${dir%*/}      # remove the trailing"/"
#       devname=${dir##*/}    # print everything after the final"/"
#       confirm_nic_info=`ifconfig $devname`
#       if [[ "$confirm_nic_info" =~ $NODE_OWN_IP_ADDRESS ]] ; then
#         echo "found interface $devname as worker node nic ip";
#         lines_num=`ls -l /sys/class/net/$devname/queues | wc -l`
#         if [ $lines_num -eq 17 ]; then
#           echo found the right rx and tx queues number in /sys/class/net/$devname/queues;
#           cpu_list_file="/sys/class/net/$devname/device/local_cpus"
#           if [ -f "$cpu_list_file" ]; then
#             local_cpu_lists=`cat $cpu_list_file`
#             echo local cpu list for nic is $local_cpu_lists
#             for (( ii=0;ii<=7;ii=ii+1 )); do
#               echo try to modify /sys/class/net/$devname/queues/rx-$ii/rps_cpus
#               if [ -s "/sys/class/net/$devname/queues/rx-$ii/rps_cpus" ]; then
#                 echo /sys/class/net/$devname/queues/rx-$ii/rps_cpus exist and not zero file size
#                 cat /sys/class/net/$devname/queues/rx-$ii/rps_cpus
#                 echo $local_cpu_lists > /sys/class/net/$devname/queues/rx-$ii/rps_cpus
#                 cat /sys/class/net/$devname/queues/rx-$ii/rps_cpus
#               fi
#             done
#           fi
#         fi
#         break;
#       fi
#     done
#   fi
# fi

# Check the instructions
if [ -z "$(lscpu | grep 'gfni\|vaes\|vpclmulqdq')" ];then
    echo "The CPU cores does not support these three instruction sets: gfni, vaes and vpclmulqdq."
fi

if [[ $CIPHER == "AES128-SHA" ]] || [[ $CIPHER == "AES128-GCM-SHA256" ]] ; then
  CERT=rsa2048
elif [[ $CIPHER == "ECDHE-ECDSA-AES128-SHA" ]] ; then
  CERT=ecdheecdsa
elif [[ $CIPHER == "ECDHE-RSA-AES128-SHA" ]] ; then
  CERT=ecdhersa
fi

mkdir -p certs
mkdir -p keys
# cert and key
if [[ $CERT == "secp384r1" ]]; then
    openssl ecparam -genkey -out keys/key_secp384r1.pem -name secp384r1 
    openssl req -x509 -new -key keys/key_secp384r1.pem -out certs/cert_secp384r1.pem -batch
    CERT=/certs/cert_secp384r1.pem
    CERTKEY=/keys/key_secp384r1.pem
elif [[ $CERT == "prime256v1" ]];then
    openssl ecparam -genkey -out keys/key_prime256v1.pem -name prime256v1
    openssl req -x509 -new -key keys/key_prime256v1.pem -out certs/cert_prime256v1.pem -batch
    CERT=/certs/cert_prime256v1.pem
    CERTKEY=/keys/key_prime256v1.pem
elif [[ $CERT == "rsa2048" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout keys/key_rsa2048.key -out certs/cert_rsa2048.crt -batch #RSA Cert
    CERT=/certs/cert_rsa2048.crt
    CERTKEY=/keys/key_rsa2048.key
elif [[ $CERT == "rsa3072" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:3072 -keyout keys/key_rsa3072.key -out certs/cert_rsa3072.crt -batch #RSA Cert
    CERT=/certs/cert_rsa3072.crt
    CERTKEY=/keys/key_rsa3072.key
elif [[ $CERT == "rsa4096" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout keys/key_rsa4096.key -out certs/cert_rsa4096.crt -batch #RSA Cert
    CERT=/certs/cert_rsa4096.crt
    CERTKEY=/keys/key_rsa4096.key
elif [[ $CERT == "ecdhersa" ]];then
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout keys/key_rsa2048.key -batch #RSA Key
    openssl req -x509 -new -key keys/key_rsa2048.key -out certs/cert_ecrsa2048.pem -batch 
    CERT=/certs/cert_ecrsa2048.pem
    CERTKEY=/keys/key_rsa2048.key
elif [[ $CERT == "ecdheecdsa" ]];then
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

if [[ $MODE == "http" ]]; then
  NGINXCONF=${NGINXCONF:-/usr/local/share/nginx/conf/nginx-http.conf}
  if [ $PORT ]; then
    echo replace $MODE port 80 to $PORT
    sed -i "s|listen 80|listen $PORT|" $NGINXCONF
  fi
elif [[ $MODE == "https" ]]; then
  if [[ $WORKLOAD == "nginx_original" ]] || [[ "$WORKLOAD" == nginx_original_ARMv* ]] || [[ $WORKLOAD == "nginx_original_MILAN" ]]; then
    NGINXCONF=${NGINXCONF:-/usr/local/share/nginx/conf/nginx-https.conf}
  elif [[ $WORKLOAD == "nginx_qatsw" ]]  || [[ $WORKLOAD == "nginx_qathw" ]]; then
    if [[ $QATACCL == "off" ]];then
      NGINXCONF=${NGINXCONF:-/usr/local/share/nginx/conf/nginx-https.conf}
    elif [[ $QATACCL == "sync" ]];then
      NGINXCONF=${NGINXCONF:-/usr/local/share/nginx/conf/nginx-https-sync-on.conf}
    elif [[ $QATACCL == "async" ]];then
      NGINXCONF=${NGINXCONF:-/usr/local/share/nginx/conf/nginx-https-async-on.conf}
    fi
  fi

  if [ $PORT ]; then
    echo replace $MODE port 443 to $PORT
    sed -i "s|listen 443|listen $PORT|" $NGINXCONF
  fi

  if [[ $PROTOCOL == "TLSv1.2" ]]; then
    sed -i "s|ssl_ciphers AES128-GCM-SHA256|ssl_ciphers $CIPHER|" $NGINXCONF
  elif [[ $PROTOCOL == "TLSv1.3" ]]; then
    sed -i "s|ssl_protocols TLSv1.2|ssl_protocols $PROTOCOL|" $NGINXCONF
    sed -i "s|ssl_ciphers AES128-GCM-SHA256|ssl_conf_command Ciphersuites $CIPHER|" $NGINXCONF
  else
    sed -i "s|ssl_protocols TLSv1.2|ssl_protocols $PROTOCOL|" $NGINXCONF
    sed -i "s|ssl_ciphers|#ssl_ciphers|" $NGINXCONF
  fi

  sed -i "s|ssl_ecdh_curve auto|ssl_ecdh_curve $CURVE|" $NGINXCONF
  sed -i "s|ssl_certificate  /certs/cert_rsa2048.crt|ssl_certificate  $CERT|" $NGINXCONF
  sed -i "s|ssl_certificate_key /keys/key_rsa2048.key|ssl_certificate_key $CERTKEY|" $NGINXCONF
fi

echo real run NGINX_WORKERS: $NGINX_WORKERS
echo real run NGINX_CPU_LISTS: $NGINX_CPU_LISTS

sed -i "s|worker_processes 1|worker_processes $NGINX_WORKERS|" $NGINXCONF
taskset -c $NGINX_CPU_LISTS nginx -c ${NGINXCONF}



# not good yet, need docker privileged & cores/NIC numa id
#numactl --physcpubind=$NGINX_CPU_LISTS --membind=0 nginx -c ${NGINXCONF}

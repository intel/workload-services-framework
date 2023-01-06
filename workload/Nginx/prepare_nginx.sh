#!/bin/bash -e

WORKLOAD=${WORKLOAD:-nginx_qatsw}
PROTOCOL=${PROTOCOL:-TLSv1.3}
QATACCL=${QATACCL:-async}
MODE=${MODE:-https}
PORT=${PORT:-443}
CERT=${CERT:-rsa2048}
CIPHER=${CIPHER:-AES128-GCM-SHA256}
NGINX_CPU_LISTS=${NGINX_CPU_LISTS:-0}

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

whole_system_cores=`nproc`
echo system cores $whole_system_cores

NGINX_WORKERS=${NGINX_WORKERS:-4}
echo "NGINX_WORKERS:${NGINX_WORKERS}"

if [ $NGINX_WORKERS -gt $whole_system_cores ]; then
  echo warning, system cores not enough for nginx worker $NGINX_WORKERS, use $whole_system_cores
  NGINX_WORKERS=$whole_system_cores
fi

if [ $NGINX_CPU_LISTS == 0 ]; then
  NGINX_LAST_CORE=$(( $NGINX_WORKERS - 1 ))
  NGINX_CPU_LISTS=0-$NGINX_LAST_CORE
fi

#ulimit -v unlimited
#ulimit -m unlimited
#ulimit -l unlimited
#ulimit -n unlimited
#ulimit -i unlimited   # those three cannot exec in docker non-privileged mode
#ulimit -s unlimited
#ulimit -u unlimited

#ufw disable

# we may need this ACCEPT before iptables -F for local static, with iptable rules
# iptables -P INPUT ACCEPT
#iptables -F

#TCP Memory
# echo 16777216                > /proc/sys/net/core/rmem_max
# echo 16777216                > /proc/sys/net/core/wmem_max
# echo 16777216                > /proc/sys/net/core/rmem_default
# echo 16777216                > /proc/sys/net/core/wmem_default
# echo 16777216 16777216 16777216  > /proc/sys/net/ipv4/tcp_rmem
# echo 538750 538750 538750  > /proc/sys/net/ipv4/tcp_wmem
# echo 16777216                    > /proc/sys/net/core/optmem_max
# echo 16777216 16777216  16777216 > /proc/sys/net/ipv4/tcp_mem
# echo 65536               > /proc/sys/vm/min_free_kbytes
#TCP Behavior
# echo 0                     > /proc/sys/net/ipv4/tcp_timestamps
# echo 0                     > /proc/sys/net/ipv4/tcp_sack
# echo 0                     > /proc/sys/net/ipv4/tcp_fack
# echo 0                     > /proc/sys/net/ipv4/tcp_dsack
# echo 0                     > /proc/sys/net/ipv4/tcp_moderate_rcvbuf
# echo 1                     > /proc/sys/net/ipv4/tcp_rfc1337
# echo 600        > /proc/sys/net/core/netdev_budget
# echo 128                   > /proc/sys/net/core/dev_weight
# echo 1                     > /proc/sys/net/ipv4/tcp_syncookies
# echo 0                     > /proc/sys/net/ipv4/tcp_slow_start_after_idle
# echo 1                     > /proc/sys/net/ipv4/tcp_no_metrics_save
# echo 1                     > /proc/sys/net/ipv4/tcp_orphan_retries
# echo 0                     > /proc/sys/net/ipv4/tcp_fin_timeout
# echo 0                     > /proc/sys/net/ipv4/tcp_tw_reuse
# echo 1                     > /proc/sys/net/ipv4/tcp_syncookies
# echo 2                           > /proc/sys/net/ipv4/tcp_synack_retries
# echo 2                     > /proc/sys/net/ipv4/tcp_syn_retries
# echo cubic                   > /proc/sys/net/ipv4/tcp_congestion_control
# echo 1                     > /proc/sys/net/ipv4/tcp_low_latency
# echo 1                     > /proc/sys/net/ipv4/tcp_window_scaling
# echo 1                     > /proc/sys/net/ipv4/tcp_adv_win_scale
#TCP Queueing
# echo 0                > /proc/sys/net/ipv4/tcp_max_tw_buckets
# echo 1025 65535            > /proc/sys/net/ipv4/ip_local_port_range
# echo 131072                > /proc/sys/net/core/somaxconn
# echo 262144            > /proc/sys/net/ipv4/tcp_max_orphans
# echo 262144           > /proc/sys/net/core/netdev_max_backlog
# echo 262144        > /proc/sys/net/ipv4/tcp_max_syn_backlog
# echo 4000000             > /proc/sys/fs/nr_open

# echo 4194304     > /proc/sys/net/ipv4/ipfrag_high_thresh
# echo 3145728     > /proc/sys/net/ipv4/ipfrag_low_thresh
# echo 30          > /proc/sys/net/ipv4/ipfrag_time
# echo 0   > /proc/sys/net/ipv4/tcp_abort_on_overflow
# echo 1           > /proc/sys/net/ipv4/tcp_autocorking
# echo 31          > /proc/sys/net/ipv4/tcp_app_win
# echo 0           > /proc/sys/net/ipv4/tcp_mtu_probing
# set selinux=disabled
# ulimit -n 1000000

# echo 262144 > /proc/sys/net/core/somaxconn
# echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

ulimit -a

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
  if [[ $WORKLOAD == "nginx_original" ]] || [[ "$WORKLOAD" == nginx_original_GRAVITON* ]] || [[ $WORKLOAD == "nginx_original_MILAN" ]]; then
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

# sed -i "s|ssl_ecdh_curve X25519|ssl_ecdh_curve  $CURVE|" $NGINXCONF
  sed -i "s|ssl_certificate  /certs/cert_rsa2048.crt|ssl_certificate  $CERT|" $NGINXCONF
  sed -i "s|ssl_certificate_key /keys/key_rsa2048.key|ssl_certificate_key $CERTKEY|" $NGINXCONF
fi

echo real run NGINX_WORKERS: $NGINX_WORKERS
echo real run NGINX_CPU_LISTS: $NGINX_CPU_LISTS

sed -i "s|worker_processes 1|worker_processes $NGINX_WORKERS|" $NGINXCONF
if [ -z "$(lscpu | grep Hypervisor)" ]; then
  echo test in local bare metal
  taskset -c $NGINX_CPU_LISTS nginx -c ${NGINXCONF}
else
  echo test in cloud
  taskset -c $NGINX_CPU_LISTS nginx -c ${NGINXCONF}
fi



# not good yet, need docker privileged & cores/NIC numa id
#numactl --physcpubind=$NGINX_CPU_LISTS --membind=0 nginx -c ${NGINXCONF}

#!/bin/bash -e

CONFIG=${CONFIG:-sw-rsa}
ASYNC_JOBS=${ASYNC_JOBS:-64}
PROCESSES=${PROCESSES:-8}
BIND_CORE=${BIND_CORE:-1c1t}

CPU_NUM=$(lscpu | grep -E "^CPU\(s\)\:" | awk '{print $2}')

if [ $PROCESSES -gt $CPU_NUM ] || [ $PROCESSES -lt 1 ];
then
    echo "Wrong input for PROCESSES"
    exit 3
fi


FIRST_CORE_SOCKET2=$(lscpu | grep "NUMA node0 CPU(s):" | awk '{print $4}' | awk '{split($1, arr, ","); print arr[2]}' | awk '{split($1, arr, "-"); print arr[1]}')
if [ "$BIND_CORE" == "1c1t" ] ; then
    LAST_CORE=$(( $PROCESSES - 1 ))
    CPU_LISTS=0-$LAST_CORE
elif [ "$BIND_CORE" == "1c2t" ] ; then
    LAST_CORE=$(( $PROCESSES/2 - 1 ))
    LAST_CORE2=$(( $FIRST_CORE_SOCKET2+$LAST_CORE ))
    CPU_LISTS="0-$LAST_CORE,$FIRST_CORE_SOCKET2-$LAST_CORE2"
else
    echo "Wrong type for core binding"
    exit 3
fi

echo CPU_LISTS:$CPU_LISTS

BIND=${BIND:-false}

if [ "$BIND" == "true" ] ; then
    BIND_CMD="numactl --physcpubind=$CPU_LISTS --membind=0 "
fi

case $CONFIG in
qatsw-rsa)
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa512
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa1024
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa2048
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa3072
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa4096
    ;;
qatsw-dsa)
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} dsa
    ;;
qatsw-ecdsa)
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdsap256
    ;;
qatsw-ecdh)
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdhx25519
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdhp256
    ;;
qatsw-aes-sha)
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha1
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha256
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha1
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha256
    ;;
qatsw-aes-gcm)
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-128-gcm
    $BIND_CMD openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-256-gcm
    ;;
sw-rsa)
    $BIND_CMD openssl speed -multi ${PROCESSES} rsa
    ;;
sw-dsa)
    $BIND_CMD openssl speed -multi ${PROCESSES} dsa
    ;;
sw-ecdsa)
    $BIND_CMD openssl speed -multi ${PROCESSES} ecdsap256
    ;;
sw-ecdh)
    $BIND_CMD openssl speed -multi ${PROCESSES} ecdhx25519 
    $BIND_CMD openssl speed -multi ${PROCESSES} ecdhp256
    ;;
sw-aes-sha)
    $BIND_CMD openssl speed -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha1
    $BIND_CMD openssl speed -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha256
    $BIND_CMD openssl speed -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha1
    $BIND_CMD openssl speed -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha256
    ;;
sw-aes-gcm)
    $BIND_CMD openssl speed -multi ${PROCESSES} -evp aes-128-gcm
    $BIND_CMD openssl speed -multi ${PROCESSES} -evp aes-256-gcm
    ;;
*)
    echo "$CONFIG unsupported"
    exit 3;;
esac

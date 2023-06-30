#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

CONFIG=${CONFIG:-sw-rsa}
ASYNC_JOBS=${ASYNC_JOBS:-64}
PROCESSES=${PROCESSES:-8}

case $CONFIG in
qat-rsa)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa512 rsa1024 rsa2048 rsa3072 rsa4096
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} rsa2048 rsa3072
    ;;
qat-dsa)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} dsa
    ;;
qat-dh)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} dh
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} dhp256
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} dhx448
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} dhx25519
    ;;
qat-hkdf)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} hkdf
    ;;
qat-prf)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} prf
    ;;
qat-chachapoly)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} chachapoly
    ;;
qat-ecx)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecx
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecxx25519
    ;;
qat-ecdsa)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdsa
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdsap256
    ;;
qat-ecdh)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdhx25519
    ;;
qat-ecdh)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdh
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdhp256
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdhx448
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} ecdhx25519
    ;;
qat-aes-sha)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha1
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha256
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha1
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha256
    ;;
qat-aes-gcm)
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-128-gcm
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-192-gcm
    openssl speed -engine qatengine -async_jobs ${ASYNC_JOBS} -multi ${PROCESSES} -evp aes-256-gcm
    ;;
sw-rsa)
    openssl speed -multi ${PROCESSES} rsa
    ;;
sw-dsa)
    openssl speed -multi ${PROCESSES} dsa
    ;;
sw-ecdsa)
    openssl speed -multi ${PROCESSES} ecdsa
    ;;
sw-ecdh)
    openssl speed -multi ${PROCESSES} ecdhx25519
    ;;
sw-aes-sha)
    openssl speed -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha1
    openssl speed -multi ${PROCESSES} -evp aes-128-cbc-hmac-sha256
    openssl speed -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha1
    openssl speed -multi ${PROCESSES} -evp aes-256-cbc-hmac-sha256
    ;;
sw-aes-gcm)
    openssl speed -multi ${PROCESSES} -evp aes-128-gcm
    openssl speed -multi ${PROCESSES} -evp aes-192-gcm
    openssl speed -multi ${PROCESSES} -evp aes-256-gcm
    ;;
*)
    echo "$CONFIG Currently unsupported, please check the supported algorithms based on the version of OpenSSL/OpenSSL*Engine currently used."
    exit 3;;
esac


#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

rm -rf certs
rm -rf keys
mkdir -p certs
mkdir -p keys
#openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 -keyout keys/key_rsa2048.key -out certs/cert_rsa2048.crt -subj "/C=CN/ST=Beijing/L=Beijing/O=Examp Inc./OU=Web Sec/CN=example.com"
#openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:4096 -keyout keys/key_rsa4096.key -out certs/cert_rsa4096.crt -subj "/C=CN/ST=Beijing/L=Beijing/O=Examp Inc./OU=Web Sec/CN=example.com"

#openssl ecparam -genkey -out keys/key_secp384r1.pem -name secp384r1 
#openssl req -x509 -new -key keys/key_secp384r1.pem -out certs/cert_secp384r1.pem -subj "/C=CN/ST=Beijing/L=Beijing/O=Examp Inc./OU=Web Sec/CN=example.com"

#openssl ecparam -genkey -out keys/key_prime256v1.pem -name prime256v1
#openssl req -x509 -new -key keys/key_prime256v1.pem -out certs/cert_prime256v1.pem -subj "/C=CN/ST=Beijing/L=Beijing/O=Examp Inc./OU=Web Sec/CN=example.com"

#########################################################
openssl req -x509 -nodes -days 3650 -newkey ec -subj "/CN=localhost" -addext "subjectAltName=DNS:nginx-server-service" -pkeyopt ec_paramgen_curve:secp384r1 -keyout keys/ecdsa.key -out certs/ecdsa.crt

# AES128-SHA & AES128-GCM-SHA256
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout keys/key_rsa2048.key -out certs/cert_rsa2048.crt -batch #RSA Cert

# ECDHE-ECDSA-AES128-SHA
openssl ecparam -genkey -out keys/key_ecdsa256.pem -name prime256v1 #ecdsa Cert
openssl req -x509 -new -key keys/key_ecdsa256.pem -out keys/cert_ecdsa256.pem -batch #finalize ecdsa Cert

# ECDHE-RSA-AES128-SHA
openssl req -x509 -new -key keys/key_rsa2048.key -out certs/cert_ecrsa2048.pem -batch 

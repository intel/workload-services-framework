#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORKLOAD=${WORKLOAD:-cdn_nginx_original}
NODE=${NODE:-2n}
MEDIA=${1:-live}
HTTPMODE=${2:-https_sync}
PROTOCOL=${PROTOCOL:-TLSv1.3}
CURVE=${CURVE:-auto}
SINGLE_SOCKET=${SINGLE_SOCKET:-"false"}
CPU_AFFI=${CPU_AFFI:-"false"}
NGINX_WORKERS=${NGINX_WORKERS:-4}
NGINX_CPU_LISTS=${NGINX_CPU_LISTS:-""}
CACHE_SIZE=${CACHE_SIZE:-"30G"}
DISK_SIZE=${DISK_SIZE:-"1000Gi"}

# Cache server configurations
if [[ "$MEDIA" == "vod" ]]; then
    STORAGE_MEDIUM="disk"
else
    STORAGE_MEDIUM="memory"
fi

if [[ "$HTTPMODE" == "https_sync" ]] || [[ "$HTTPMODE" == "https_async" ]]; then
    SYNC=$(echo ${HTTPMODE}|cut -d_ -f2)
    HTTPMODE=$(echo ${HTTPMODE}|cut -d_ -f1)
else
    SYNC="sync"
fi

if [[ "$WORKLOAD" == "cdn_nginx_original" ]]; then
  NGINX_IMAGE="Dockerfile.2.nginx.original"
elif [[ "$WORKLOAD" == "cdn_nginx_qatsw" ]]; then
  NGINX_IMAGE="Dockerfile.2.nginx.qatsw"
elif [[ "$WORKLOAD" == "cdn_nginx_qathw" ]]; then
  NGINX_IMAGE="Dockerfile.2.nginx.qathw"
fi

# qathw setting, for kerner version >= 5.11: qat.intel.com/generic; for kernel version >= 5.17 qat.intel.com/cy:
QAT_RESOURCE_TYPE=${QAT_INSTANCE_TYPE:-"qat.intel.com/cy"}
QAT_RESOURCE_NUM=${QAT_RESOURCE_NUM:-16}

if [[ "$PROTOCOL" == "TLSv1.3" ]]; then
  CIPHER=${CIPHER:-TLS_AES_128_GCM_SHA256}
else
  CIPHER=${CIPHER:-AES128-GCM-SHA256}
fi

if [[ "$CIPHER" == "ECDHE-ECDSA-AES128-SHA" ]] ; then
  CERT=ecdheecdsa
elif [[ "$CIPHER" == "ECDHE-RSA-AES128-SHA" ]] ; then
  CERT=ecdhersa
fi
CERT=${CERT:-rsa2048}


# Client tunable parameters
NICIP_W1=${NICIP_W1:-192.168.2.200}
NICIP_W2=${NICIP_W2:-192.168.2.201}
NUSERS=${NUSERS:-400}
NTHREADS=$NGINX_WORKERS

if [[ "${TESTCASE}" =~ ^test.*_gated$ ]]; then
    NUSERS=1
    GATED="gated"
elif [[ "${TESTCASE}" =~ ^test.*_pkm$ ]]; then
    NUSERS=400
fi

echo "WORKLOAD=$WORKLOAD"
echo "NODE=$NODE"
echo "MEDIA=$MEDIA"
echo "STORAGE_MEDIUM=$STORAGE_MEDIUM"
echo "HTTPMODE=$HTTPMODE"
echo "SYNC=$SYNC"
echo "NGINX_IMAGE=$NGINX_IMAGE"
echo "QAT_RESOURCE_TYPE=$QAT_RESOURCE_TYPE"
echo "QAT_RESOURCE_NUM=$QAT_RESOURCE_NUM"
echo "PROTOCOL=$PROTOCOL"
echo "CERT=$CERT"
echo "CIPHER=$CIPHER"
echo "CURVE=$CURVE"
echo "GATED=$GATED"
echo "NICIP_W1=$NICIP_W1"
echo "NICIP_W2=$NICIP_W2"
echo "NUSERS=$NUSERS"
echo "NTHREADS=$NTHREADS"
echo "SINGLE_SOCKET=$SINGLE_SOCKET"
echo "CPU_AFFI=$CPU_AFFI"
echo "NGINX_WORKERS=$NGINX_WORKERS"
echo "NGINX_CPU_LISTS=$NGINX_CPU_LISTS"
echo "CACHE_SIZE=$CACHE_SIZE"
echo "DISK_SIZE=$DISK_SIZE"

if [[ "$HTTPMODE" == "http" ]]; then
    HTTPPORT=8080
    NGINXTYPE="http"
else
    HTTPPORT=8443
    if [[ "$SYNC" == "sync" ]]; then
        NGINXTYPE="https"
    else
        NGINXTYPE="async-on"
    fi
fi

# The first parameter is for memory test, the second parameter is for disk test.
# Formula for the second parameter:  WRKLOG_TIMEOUT=DURATION+360 (memory) WRKLOG_TIMEOUT=DURATION+660 (disk)
if [[ "$STORAGE_MEDIUM" == "memory" ]]; then
    DURATION=60
    WRKLOG_TIMEOUT=420
else
    DURATION=120
    WRKLOG_TIMEOUT=780

    # To make the test time shorter, you can use following parameters instead:
    # DURATION=60
    # WRKLOG_TIMEOUT=720
fi

# EMON capture range
EVENT_TRACE_PARAMS="roi,begin_region_of_interest,end_region_of_interest"

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(WORKLOAD NODE HTTPMODE SYNC GATED STORAGE_MEDIUM NICIP_W1 NICIP_W2 NUSERS NTHREADS NGINX_IMAGE HTTPPORT NGINXTYPE DURATION WRKLOG_TIMEOUT QAT_RESOURCE_TYPE QAT_RESOURCE_NUM PROTOCOL CERT CIPHER CURVE SINGLE_SOCKET CPU_AFFI NGINX_WORKERS NGINX_CPU_LISTS CACHE_SIZE DISK_SIZE)

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DWORKLOAD=$WORKLOAD -DNODE=$NODE -DHTTPMODE=$HTTPMODE -DSYNC=$SYNC -DGATED=$GATED -DSTORAGE_MEDIUM=$STORAGE_MEDIUM -DNICIP=$NICIP_W1 -DNICIP_W2=$NICIP_W2 -DNUSERS=$NUSERS -DNTHREADS=$NTHREADS -DNGINX_IMAGE=$NGINX_IMAGE -DHTTPPORT=$HTTPPORT -DNGINXTYPE=$NGINXTYPE -DDURATION=$DURATION -DWRKLOG_TIMEOUT=$WRKLOG_TIMEOUT -DQAT_RESOURCE_TYPE=$QAT_RESOURCE_TYPE -DQAT_RESOURCE_NUM=$QAT_RESOURCE_NUM -DPROTOCOL=$PROTOCOL -DCERT=$CERT -DCIPHER=$CIPHER -DCURVE=$CURVE -DSINGLE_SOCKET=$SINGLE_SOCKET -DCPU_AFFI=$CPU_AFFI -DNGINX_WORKERS=$NGINX_WORKERS -DNGINX_CPU_LISTS=$NGINX_CPU_LISTS -DCACHE_SIZE=$CACHE_SIZE -DDISK_SIZE=$DISK_SIZE"

JOB_FILTER="job-name=benchmark"

TIMEOUT=${TIMEOUT:-3000}
. "$DIR/../../script/validate.sh"

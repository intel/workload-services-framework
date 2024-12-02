#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

for ICP_ROOT in /opt/intel/QAT /QAT; do
    USDM="$ICP_ROOT/build/usdm_drv.ko"
    [ -e "$USDM" ] && break || continue
done

if [ ! -e "$USDM" ]; then
    echo "Failed to locate usdm_drv.ko"
    exit 3
fi

nodeids=($("$ICP_ROOT/build/adf_ctl" status | grep qat_dev | sed -e 's/.*node_id: //' -e 's/,.*//'))
DEVICES=${DEVICES:-${#nodeids[*]}}
SECTION_NAME=${SECTION_NAME:-SHIM}
SERVICES_ENABLED=${SERVICES_ENABLED:-sym}
ASYNC_JOBS=${ASYNC_JOBS:-64}
LIMIT_DEV_ACCESS=${LIMIT_DEV_ACCESS:-0}
CONFIG_FILE="${CONFIG_FILE:-/etc/4xxx_dev?.conf}"
ENABLE_HUGEPAGES=${ENABLE_HUGEPAGES:-True}

CY_INSTANCES=${CY_INSTANCES:-0}
if [ $CY_INSTANCES -gt 8 ]; then
    CY_INSTANCES=8
fi

DC_INSTANCES=${DC_INSTANCES:-0}
if [ $DC_INSTANCES -gt 8 ]; then
    DC_INSTANCES=8
fi

PROCESSES=${PROCESSES:-1}
if [ $PROCESSES -gt 64 ]; then
    PROCESSES=64
fi

if [ $(( $CY_INSTANCES * $PROCESSES )) -gt 64 ]; then
    CY_INSTANCES=$(( 64 / $PROCESSES)) 
fi

if [ $(( $DC_INSTANCES * $PROCESSES )) -gt 64 ]; then
    DC_INSTANCES=$(( 64 / $PROCESSES)) 
fi

get_core () {
    coreids=($(lscpu -e=NODE,CPU | awk -v n=$2 '$1==n{print$2}'))
    eval "q=\$ct_${1}_${2}"
    core_id=${coreids[$q]}
    eval "ct_${1}_${2}=$((q+1))"
}

for d in $(seq 0 $(( $DEVICES - 1 ))); do
    config_file="${CONFIG_FILE/\?/$d}"

    echo "=== $config_file ==="
    tee "$config_file" <<EOF
[GENERAL]
ServicesEnabled = ${SERVICES_ENABLED//,/;}
ConfigVersion = 2
NumCyAccelUnits = 0
NumDcAccelUnits = 6
NumInlineAccelUnits = 0
CyNumConcurrentSymRequests = 512
CyNumConcurrentAsymRequests = 64
DcNumConcurrentRequests = 512
statsGeneral = 1
statsDh = 1
statsDrbg = 1
statsDsa = 1
statsEcc = 1
statsKeyGen = 1
statsDc = 1
statsLn = 1
statsPrime = 1
statsRsa = 1
statsSym = 1
statsMisc = 1
AutoResetOnError = 0

[KERNEL]
NumberCyInstances = 0
NumberDcInstances = 0

[$SECTION_NAME]
NumberCyInstances = $CY_INSTANCES
NumberDcInstances = $DC_INSTANCES
NumProcesses = $PROCESSES
LimitDevAccess = $LIMIT_DEV_ACCESS
EOF

    for cy in $(seq 0 $(( $CY_INSTANCES - 1 ))); do
        get_core cy ${nodeids[$d]}
        tee -a "$config_file" <<EOF
Cy${cy}Name = "Cy${cy}"
Cy${cy}IsPolled = 1
Cy${cy}CoreAffinity = $core_id
EOF

    done

    for dc in $(seq 0 $(( $DC_INSTANCES - 1 ))); do
        get_core dc ${nodeids[$d]}
        tee -a "$config_file" <<EOF
Dc${dc}Name = "Dc${dc}"
Dc${dc}IsPolled = 1
Dc${dc}CoreAffinity = $core_id
EOF

    done
done

"$ICP_ROOT/build/qat_service" restart
if [ $(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages) -lt 4096 ] && [ $ENABLE_HUGEPAGES = "True" ]; then
    echo 4096 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
fi
rmmod usdm_drv || echo -n ""
if [ $ENABLE_HUGEPAGES = "True" ]; then
    insmod "$USDM" max_huge_pages=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages) max_huge_pages_per_process=224
fi
echo "#Devices,#Services,#CyInstances,#DcInstances,#Processes,#AsyncJobs"
echo "$DEVICES,$CY_INSTANCES,$DC_INSTANCES,$PROCESSES,$ASYNC_JOBS" 
CSV_DATA="Devices:$DEVICES;Services:$SERVICES_ENABLED;#CyInstances:$CY_INSTANCES;#DcInstances:$DC_INSTANCES;#Processes:$PROCESSES;THREADS:$THREADS;#AsyncJobs:$ASYNC_JOBS" DOCKER_OPTIONS="-e PROCESSES=$PROCESSES -e ASYNC_JOBS=$ASYNC_JOBS -e THREADS=$THREADS" $*

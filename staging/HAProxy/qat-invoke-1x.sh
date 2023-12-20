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
SERVICES_ENABLED=${SERVICES_ENABLED:-cy}
LIMIT_DEV_ACCESS=${LIMIT_DEV_ACCESS:-0}
CONFIG_FILE="${CONFIG_FILE:-/etc/c6xx_dev?.conf}"


CY_INSTANCES=${CY_INSTANCES:-0}
#if [ $CY_INSTANCES -gt 8 ]; then
#    CY_INSTANCES=8
#fi

DC_INSTANCES=${DC_INSTANCES:-0}
# if [ $DC_INSTANCES -gt 8 ]; then
#     DC_INSTANCES=8
# fi

PROCESSES=${PROCESSES:-4}
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
    #eval "q=\$ct_${1}_${2}"
    core_id=${coreids[$1]}
    #eval "ct_${1}_${2}=$((q+1))"
}

for d in $(seq 0 $(( $DEVICES - 1 ))); do
    config_file="${CONFIG_FILE/\?/$d}"

    echo "=== $config_file ==="
    tee "$config_file" <<EOF
[GENERAL]
ServicesEnabled = ${SERVICES_ENABLED//,/;}
ServicesProfile = DEFAULT
ConfigVersion = 2

#Default values for number of concurrent requests*/
CyNumConcurrentSymRequests = 512
CyNumConcurrentAsymRequests = 64

#Statistics, valid values: 1,0
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


# Specify size of intermediate buffers for which to
# allocate on-chip buffers. Legal values are 32 and
# 64 (default is 64). Specify 32 to optimize for
# compressing buffers <=32KB in size.
DcIntermediateBufferSizeInKB = 64

# This flag is to enable device auto reset on heartbeat error
AutoResetOnError = 0

##############################################
# Kernel Instances Section
##############################################
[KERNEL]
NumberCyInstances = 0
NumberDcInstances = 0

##############################################
# User Process Instance Section
##############################################

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

adf_ctl restart
echo "#Devices,#CyInstances,#DcInstances,#Processes,"
echo "$DEVICES,$CY_INSTANCES,$DC_INSTANCES,$PROCESSES" 

#!/usr/bin/env bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Script configure IAA devices

# Usage : ./configure_iaa_user <mode> <start,end> <wq_size>
# mode: 0 - shared, 1 - dedicated
# devices: 0 - all devices or start and end device number. 
#  For example, 1, 7 will configure all the Socket0 devices in host or 0, 3  will configure all the Socket0 devices in guest
#               9, 15  will configure all the Socket1 devices and son on
#               1  will conigure only device 1
# wq_size: 1-128
#
# select iax config
#

# count iax instances
#
iax_dev_id="0cfe"
num_iax=$(lspci -d:${iax_dev_id} | wc -l)
echo "Found ${num_iax} IAX instances"

dedicated=${1:-0}; 
device_num=${2:-$num_iax}; 
wq_size=${3:-128}; 

if [ ${dedicated} -eq 0 ]; then
    mode="shared"
else
    mode="dedicated"
fi
#check whether running on host or guest and if dsa exist
hyp=`lscpu | grep -c hypervisor`
dsa=`lspci | grep -c 0b25`
#set first,step counters to correctly enumerate iax devices based on whether running on guest or host with or without dsa
first=0
step=1
[[ $hyp -eq 0 || $dsa -gt 0 ]] && first=1 && step=2
[[ $hyp -eq 0 ]] && for ((i = ${first}; i < ${step} * ${num_iax}; i += ${step})); do accel-config remove-mdev iax$i all 2> /dev/null;done #remove any mdev
echo "first index: ${first}, step: ${step}, hyp: $hyp"


#
# disable iax wqs and devices
#
echo "Disable IAX"

for ((i = ${first}; i < ${step} * ${num_iax}; i += ${step})); do
    echo disable wq iax${i}/wq${i}.0 >& /dev/null
    accel-config disable-wq iax${i}/wq${i}.0 >& /dev/null
    echo disable iax iax${i} >& /dev/null
    accel-config disable-device iax${i} >& /dev/null
done

echo "Configuring mode: ${mode}"
echo "Configuring devices: ${device_num}"
echo "Configuring wq_size: ${wq_size}"

if [ ${device_num} == $num_iax ]; then
    echo "Configuring all devices"
    start=${first}
    end=$(( ${step} * ${num_iax} ))
else
    echo "Configuring devices ${device_num}"
    declare -a array=($(echo ${device_num}| tr "," " ")) 
    start=${array[0]}
    if [ ${array[1]}  ];then
        end=$((${array[1]} + 1 ))
    else
        end=$((${array[0]} + 1 ))
    fi
fi


#
# enable all iax devices and wqs
#
echo "Enable IAX ${start} to ${end}"
for ((i = ${start}; i < ${end}; i += ${step})); do
    # Config  Engines and groups

    if [ $hyp -eq 0 ]; then
        accel-config config-engine iax${i}/engine${i}.0 --group-id=0
        accel-config config-engine iax${i}/engine${i}.1 --group-id=0
        accel-config config-engine iax${i}/engine${i}.2 --group-id=0
        accel-config config-engine iax${i}/engine${i}.3 --group-id=0
        accel-config config-engine iax${i}/engine${i}.4 --group-id=0
        accel-config config-engine iax${i}/engine${i}.5 --group-id=0
        accel-config config-engine iax${i}/engine${i}.6 --group-id=0
        accel-config config-engine iax${i}/engine${i}.7 --group-id=0

        # Config WQ: group 0, size = 128, priority=10, mode=shared, type = user, name=iax_crypto, threashold=128, block_on_fault=1, driver_name=user
        accel-config config-wq iax${i}/wq${i}.0 -g 0 -s $wq_size -p 10 -m ${mode} -y user -n user${i} -t $wq_size -b 1 -d user
    else
        accel-config config-wq  iax${i}/wq${i}.0 -y user -n user${i} -d user
    fi

    echo enable device iax${i}
    accel-config enable-device iax${i}
    echo enable wq iax${i}/wq${i}.0
    accel-config enable-wq iax${i}/wq${i}.0
done


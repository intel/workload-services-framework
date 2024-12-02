#!/bin/bash
# time synchronize
#ntpdate 133.133.133.1
#sntp -P no -r 133.133.133.1
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# get processor model name
CPUMODE=`grep "model name" /proc/cpuinfo | sort -u | tr -s ' ' | awk 'BEGIN{FS=": "} {print $2}'`
echo "CPU MODE: " $CPUMODE

# get processor frequency
CPUFREQ=`awk '{printf "%.2f", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq`
echo "    Frequency:" $CPUFREQ GHz

# get cache size
CACHESIZE=`grep 'cache size' /proc/cpuinfo | sort -u | awk '{print $4/1024}'`
echo "    Cache size:" $CACHESIZE MB

# get number of sockets
NUMSOCK=${1:-`grep 'physical id' /proc/cpuinfo | sort -u | wc -l`}
echo $NUMSOCK sockets

# get id of each socket
socketidlist=`grep "physical id" /proc/cpuinfo | sort -u | awk '{(es=="")?es=$4:es=es" "$4} END{print es}'`
echo "    IDs of Sockets:" $socketidlist

# get number of logical cores
NUMPROC=${1:-`grep -c 'processor' /proc/cpuinfo`}
echo "   " $NUMPROC logical cores in total

# get number of physical cores per socket
NUMPHYSCORE=${1:-`grep 'core id' /proc/cpuinfo | sort -u | wc -l`}
#NUMPHYSCORE=${1:-`grep 'cpu cores' /proc/cpuinfo | sort -u | awk '{print $4}'`}
#TOTALCORES=${1:-`grep 'core id' /proc/cpuinfo | wc -l`}
#NUMPHYSCORE=`expr $TOTALCORES / $NUMSOCK`
echo "   " $NUMPHYSCORE physical cores per socket

# get number of logical cores per socket
firstsocket=`echo $socketidlist | cut -d ' ' -f1`
NUMLOGICORE=${1:-`awk '/physical id\t: '$firstsocket'/' /proc/cpuinfo | wc -l`}
# or
#NUMLOGICORE=${1:-`expr $NUMPROC / $NUMSOCK`}
echo "   " $NUMLOGICORE logical cores per socket

# get number of numa nodes
NUMNODE=${1:-`numactl --hardware | awk '/available:/ {print $2}'`}
if [ $NUMNODE -eq 1 ]
then
    echo NUMA is off
    NUMA=0
else
    echo NUMA is ON, there are $NUMNODE NUMA nodes.
    NUMA=1
fi

if [ $NUMPHYSCORE -eq $NUMLOGICORE ]
then
    echo Hyper-Threading is off
    HT=0
else
    echo Hyper-Threading is ON
    HT=1
fi

if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies ]
then
    #TURBO=`awk '{f1=sprintf("%.2f",$1/1000000);f2=sprintf("%.2f",$2/1000000);(f1==f2&&$1>$2)?turbo=1:turbo=0;print turbo}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies`
    TURBO=`awk '{($1-$2==1000)?turbo=1:turbo=0;print turbo}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies`
    if [ $TURBO -eq 1 ]
    then
	echo Turbo is ON
    else
	echo Turbo is off
    fi
else
    echo EIST is disabled
    TURBO=0
fi

socketnum=0
for socketid in $socketidlist; do
#    core[$socketnum]=`awk 'BEGIN{FS="\n";RS=""} /physical id\t: '$socketid'/ {print $1}' /proc/cpuinfo | awk '{(es=="")?es=$3:es=es","$3} END {print es}'`
    core[$socketnum]=`grep -E "processor|physical id|core id|cpuid" /proc/cpuinfo | grep -A 2 "processor" | awk 'BEGIN{FS="\n";RS="--\n"} /physical id\t: '$socketid'/ {print $2,a[$2$3]++,$3,$1}' | sort | awk '{(es=="")?es=$12:es=es","$12} END {print es}'`
    echo  Cores on Socket $socketnum: ${core[socketnum]} | tr ',' ' '
    socketnum=`expr $socketnum + 1`
done

#socketnum=$NUMSOCK
#while (( $socketnum > ${2:-0} )); do
#    corenum=`awk 'BEGIN{print '$socketnum'*'$NUMLOGICORE'}' /dev/null`
#    cpuset=`grep -E "processor|physical id|core id|cpuid" /proc/cpuinfo | grep -A 2 "processor" | awk 'BEGIN{FS="\n";RS="--\n"} {print $2,$3,$1}' | awk '{print $4,$8,a[$4$8]++,$11}' | sort -r | awk 'NR<='$corenum' {(es=="")?es=$4:es=es","$4} END{print es}'`
#    echo $corenum
#    echo $cpuset
#    socketnum=`expr $socketnum / 2`
#done

socketnum=$NUMSOCK
while (( $socketnum > ${1:-0} )); do
    socketid=0
    cpuset[$socketnum]=${core[0]}
    while (( $socketid < $socketnum - 1 )); do
	socketid=`expr $socketid + 1`
	cpuset[$socketnum]=${cpuset[socketnum]}","${core[$socketid]}
    done
    echo Cores on $socketnum of Sockets: ${cpuset[socketnum]} | tr ',' ' '
    socketnum=`expr $socketnum / 2`
done

sudo /usr/sbin/dmidecode -t 0,2,17 > dmiinfo
#get base board info
BOARD=`grep -i -A3 "base board" dmiinfo | awk 'BEGIN{FS=": "} /Manufacturer|Product Name/ {(es=="")?es=$2:es=es", "$2} END{print es}'`
echo MotherBoard: $BOARD

#get bios version
BIOS=`grep -i -A3 "bios info" dmiinfo | awk 'BEGIN{FS=": "} /Version|Release Date/ {(es=="")?es=$2:es=es", "$2} END{print es}'`
echo "BIOS:" $BIOS

#get memory info
DIMMNUM=`grep -i -A16 "memory device$" dmiinfo | grep -c 'Size: [0-9]'`
DIMMSIZE=`grep -i -A16 "memory device$" dmiinfo | grep -m 1 'Size: [0-9]' | awk '{print $2/1024}'`
DIMMTYPE=`grep -i -A16 "memory device$" dmiinfo | grep -m 1 'Type:' | awk 'BEGIN{FS=": "} {print $2}'`
DIMMSPEED=`grep -m 1 'Speed' dmiinfo | awk '{print $2}'`
DIMMPART=`grep -m 1 'Part Number: [[:alnum:]]' dmiinfo | awk '{print $3}'`
rm -f dmiinfo
echo Memory: ${DIMMNUM}x ${DIMMSIZE}GB ${DIMMTYPE}-${DIMMSPEED}MHz, ${DIMMPART}

#OS=`[ -e /etc/issue ] && head -n 1 /etc/issue`
#OS=`[ -e /etc/issue ] && cat /etc/issue | sed '/^$/d' | head -n 1`

OS=`hostnamectl | grep Operating`
echo $OS
KERNEL=`uname -rm`
echo "   " Kernel: $KERNEL

MACHINECONF="$CPUMODE, ${CPUFREQ}GHz, ${CACHESIZE}MB, ${DIMMNUM}x${DIMMSIZE}GB ${DIMMTYPE}-${DIMMSPEED}, $TURBO, $HT, $NUMA"
echo $MACHINECONF

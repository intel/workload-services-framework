#!/bin/bash -e
#set -x
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# VIRTIO_V1 version
WORK_DIR=/var/tmp
cd $WORK_DIR
BASE_DIR=/opt/rook/benchmark/
SPDK_DIR=$BASE_DIR/spdk
BENCHMARK_LOGS=$BASE_DIR/daemonset-logs
#CPU_MASK_VHOST_DEV=(1 2 4)
ROL_NUM=0
VHOST_NUM=${VHOST_CPU_NUM:-3}
BS=${VHOST_DEV_BS:-512}
POOL=replicapool

# logs directory
mkdir -p "$BENCHMARK_LOGS"

#args: None
delete_spdk () {
    echo "Deleting SPDK-Vhost because pod has been deleted..."
    rm -rf /var/tmp/spdk.sock
    rm -rf /var/tmp/spdk.sock.lock
    rm -rf /var/tmp/vhost.message
    rm -rf /var/tmp/vhost.tag
}

# args:
#   $1 - exit code
data_collection_and_exit () {
    exit_code=$1
    cd "$BENCHMARK_LOGS" && echo ${exit_code} > status
}

# Check ceph status
check_ceph_status () {
    if [ "`ceph -s |grep health |awk '{print $2}'`" != "HEALTH_OK" ];then
        echo "Ceph not healthy, please check Ceph status!"
        echo "This pod will sleep infinity"
        data_collection_and_exit 1
        exit -1
    fi
}

rev_2to16 () {
    str=$1
    i=0
    len=`echo ${#str} / 4 |bc`

    while [ $i -le $len ];do
        tmp=$(echo $str |cut -b1-4)
        MASK_BIN=$(echo $tmp |rev)
        MASK_HEX[$i]=$(echo "obase=16;$(echo $((2#$MASK_BIN)))"|bc)
        str=$(echo $str |cut -b5-)
        i=$(($i+1))
    done

    while [ $i -ge 0 ];do
        res=$res${MASK_HEX[$i]}
        i=$(($i-1))
    done
    echo $res
}

# Create spdk bdev
# $1: pool name
# $2: rbd image name
# $3: rbd image size
# $4: rbd image block size
# $5: CPU mask for spdk-bdev
spdk_bdev_create(){
    cd $SPDK_DIR
    if [ -z `ceph osd pool ls |grep $1` ];then
        ceph osd pool create $1
        rbd pool init $1
    fi
    if [ -z `rbd ls $1 |grep $2` ];then
        rbd create --size $3 $1/$2
        sleep 1
        DEV_NAME=`./scripts/rpc.py bdev_rbd_create $1 $2 $4 | grep Ceph`
        ./scripts/rpc.py vhost_create_blk_controller --cpumask 0x$5 vhost.$2 $DEV_NAME
        if [ "$?" -eq 0 ];then
            echo "BDEV create succefully!"
        fi
    else
        echo "*******WARNING: BDEV already exists"
    fi
}


# If the volumne is not mounted from PV through CSI, then it's should initial with toolbox.

echo "Initialize test with toolbox"
/bin/bash -c -m $BASE_DIR/toolbox.sh &
sleep 1
echo "End of the initialization!"

# Check ceph status
if [ "$CHECK_CEPH_STATUS" = "1" ];then
    check_ceph_status
else
    echo "Do not check ceph status..."
fi

# Calculate SPDK-Vhost CPU mask (HEX form)
# $CPU_MASK_VHOST: CPU_MASK for SPDK-Vhost
# ${CPU_MASK[$i]}: CPU_MASK for each SPDK-Vhost core
CPU_AVA=$(cat /proc/self/status |grep "Cpus_allowed:" |sed 's/,//g' |awk '{print $2}')

tmp=0
i=0
while [ "$tmp" -lt "$VHOST_NUM" ];do
    a=$(( 1<<i & 0x$CPU_AVA))
    if [ $a -eq 0 ];then
        SPDK_MASK=$(echo "$SPDK_MASK""0")
        MASK_TMP=$(echo "$MASK_TMP""0")
    else
        SPDK_MASK=$(echo "$SPDK_MASK""1")
        CPU_MASK[$tmp]=$(echo "$MASK_TMP""1")
        CPU_MASK[$tmp]=$(rev_2to16 ${CPU_MASK[$tmp]})
        MASK_TMP=$(echo "$MASK_TMP""0")
        tmp=$(($tmp+1))
    fi
    i=$(($i+1))
done

CPU_MASK_VHOST=$(rev_2to16 $SPDK_MASK)

cd $SPDK_DIR
HUGEMEM=4096 ./scripts/setup.sh
./build/bin/vhost -S /var/tmp -s 1024 -m 0x$CPU_MASK_VHOST &
sleep 3

if [ -f /var/tmp/vhost.tag ];then
    echo "vhost.tag exists"
else
    touch /var/tmp/vhost.tag
fi

trap 'delete_spdk' SIGTERM ERR

# Polling for signal sent by kubevirt and create or delete spdk bdev accordingly

while true;do
    while [ -f /var/tmp/vhost.message ];do
        if [ `cat /var/tmp/vhost.message | grep WorkItemStatus= | awk -F "=" '{print $2}'` == "New" ];then
            TIME=$(date +'%y-%m-%d-%H-%M')
            UUID=($(cat /var/tmp/vhost.message | grep UUID= |awk -F "=" '{print $2}' | sed 's/\"//g'))
            NAME=($(cat /var/tmp/vhost.message | grep NAME= |awk -F "=" '{print $2}' | sed 's/\"//g'))
            SIZE_ori=($(cat /var/tmp/vhost.message | grep CAPACITY= |awk -F "=" '{print $2}'| sed 's/\"//g'))
            UNIT=($(cat /var/tmp/vhost.message | grep UNIT= |awk -F "=" '{print $2}'| sed 's/\"//g'))
            QUEUE_NUM=`cat /var/tmp/vhost.message |grep WorkItem= |awk -F "Queue" '{print $2}' `
            INDEX=$(($QUEUE_NUM-1))
            sed -i 's/WorkItemStatus=New/WorkItemStatus=WIP/g' /var/tmp/vhost.message
            if [ "${UNIT[$INDEX]}" == "G" ];then
                SIZE=`expr ${SIZE_ori[$INDEX]} \* 1024`
            elif [ "${UNIT[$INDEX]}" == "M" ];then
                SIZE=${SIZE_ori[$INDEX]}
            fi
            echo "Device ${INDEX} created. Size=${SIZE}Mi"
            vhost_index=$(($ROL_NUM % $VHOST_NUM))
            ROL_NUM=$(($ROL_NUM+1))
            spdk_bdev_create $POOL ${NAME[$INDEX]} $SIZE $BS ${CPU_MASK[$vhost_index]}
            if [ $? -eq 0 ];then
                sed -i 's/WorkItemStatus=WIP/WorkItemStatus=Complete/g' /var/tmp/vhost.message
                sed -i "s/RESULT={}/RESULT={status:complete;vhost_ctrl:vhost.${NAME[$INDEX]};size:${SIZE_ori[$INDEX]}${UNIT[$INDEX]};time:$TIME;uuid:${UUID[$INDEX]};}/g" /var/tmp/vhost.message
                sed -i "s/WORKSTATUS=NEW/WORKSTATUS=complete/g" /var/tmp/vhost.message
            else
                echo "ERROR: SPDK-Vhost create failure!"
            fi
        fi
        if [ `cat /var/tmp/vhost.message | grep WorkItemStatus= | awk -F "=" '{print $2}'` == "Delete" ];then
            sed -i 's/WorkItemStatus=Delete/WorkItemStatus=Deleting/g' /var/tmp/vhost.message
            QUEUE=`cat /var/tmp/vhost.message |grep WorkItem= |awk -F "=" '{print $2}'`
            #only substitute first one
            sed -i '0,/WORKSTATUS=Delete/{s/WORKSTATUS=Delete/WORKSTATUS=Deleting/}' /var/tmp/vhost.message
            IMAGE_DELETE=`cat /var/tmp/vhost.message |grep $QUEUE: -A8 |awk -F "=" '{if($0 ~/NAME/) print $2}'`
            bash ${BASE_DIR}/clean_vhost_blk.sh vhost.$IMAGE_DELETE $POOL $IMAGE_DELETE &
        fi
	sleep 1
    done
sleep 1
done

sleep infinity

#!/bin/bash -e
#set -x
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WORK_DIR=/opt/rook/benchmark
SPDK_DIR=$WORK_DIR/spdk
VHOST_CONTROLLER=$1
POOL_NAME=$2
RBD_IMAGE=$3

cd $SPDK_DIR

#clean vhost_controller
if [ -n "`scripts/rpc.py vhost_get_controllers|grep $VHOST_CONTROLLER`" ];then
    scripts/rpc.py vhost_delete_controller $VHOST_CONTROLLER
else
    echo "*****WARNING: vhost-controller not found"
fi

# clean rbd images
if [ -n "`rbd ls $POOL_NAME |grep $RBD_IMAGE`" ];then
    rbd rm $POOL_NAME/$RBD_IMAGE
else
    echo "WARNING: RBD_image not found"
fi
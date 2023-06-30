#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

for i in $(seq ${disk_count}); do
    devdisk="${device_root}-$(( i - 1 ))"
    until [ -e $devdisk ]; do sleep 1s; done

    if [ -x "/usr/sbin/mkfs.${disk_format}" ]; then
        devpath="/mnt/disk$i"
        mkdir -p $devpath
        if ! grep -q -F $devdisk /etc/fstab; then
            parted -s $devdisk \
                mklabel gpt \
                mkpart primary ${disk_format} 0% 100%
            sync
            devpart="$(lsblk -l -p $devdisk | tail -n1 | cut -f1 -d' ')"
            devuuid="$(uuidgen)"
            if [ "${disk_format}" == "xfs" ]; then
                yes | mkfs.${disk_format} -m uuid=$devuuid $devpart
            else
                yes | mkfs.${disk_format} -m 0 -U $devuuid $devpart
            fi
            echo "UUID=$devuuid $devpath auto defaults,nofail 0 2" >> /etc/fstab
        fi
        mount -a
        chown ${disk_user}.${disk_group} $devpath
    fi
done

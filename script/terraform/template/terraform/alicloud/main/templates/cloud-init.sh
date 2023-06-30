#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ ! -d /home/${user_name} ]; then
    echo "${user_name} ALL = NOPASSWD: ALL" >> /etc/sudoers
    useradd ${user_name} --home /home/${user_name} --shell /bin/bash -m
fi

mkdir -p /home/${user_name}/.ssh
echo "${public_key}" > /home/${user_name}/.ssh/authorized_keys
chown -R ${user_name}:${user_name} /home/${user_name}/.ssh
chmod 700 /home/${user_name}/.ssh
chmod 400 /home/${user_name}/.ssh/authorized_keys

%{ for disk in disks ~}
    while true; do
        if [ -n "${disk.serial}" ]; then
            device="$(lsblk -l -p -o +SERIAL | grep -F ${disk.serial} | cut -f1 -d' ')"
            [ -b "$device" ] && break
        else
            device="/dev/doesnotexist"
            for device1 in $(lsblk -l -p | grep " disk " | grep nvme | cut -f1 -d' '); do
                [ -b "$device1" ] && [ -z "$(mount | grep -E "^$device1")" ] && device=$device1 && break
            done
            [ -b "$device" ] && break
        fi
        sleep 1s
    done

    if [ -x "/usr/sbin/mkfs.${disk_format}" ]; then
        mkdir -p ${disk.mount_path}
        if ! grep -q -F ${disk.mount_path} /etc/fstab; then
            parted -s $device \
                mklabel gpt \
                mkpart primary ${disk_format} 0% 100%
            sync
            devpart="$(lsblk -l -p $device | tail -n1 | cut -f1 -d' ')"
            devuuid="$(uuidgen)"
            if [ "${disk_format}" == "xfs" ]; then
                yes | mkfs.${disk_format} -m uuid=$devuuid $devpart
            else
                yes | mkfs.${disk_format} -m 0 -U $devuuid $devpart
            fi
            echo "UUID=$devuuid ${disk.mount_path} auto defaults,nofail 0 2" >> /etc/fstab
        fi
        mount -a
        chown ${user_name}.${user_name} ${disk.mount_path}
    fi
%{ endfor ~}


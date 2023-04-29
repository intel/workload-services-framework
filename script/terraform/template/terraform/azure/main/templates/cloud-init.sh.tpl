#!/bin/bash

for i in $(seq ${disk_count}); do
    while true; do
        if [ -n "${device_root}" ]; then
            devdisk="${device_root}/lun$(( i - 1 ))"
            [ -e $devdisk ] && break
        else
            devdisk="/dev/does_not_exist"
            for device1 in $(lsblk -l -p | grep " disk " | grep nvme | cut -f1 -d' '); do
                [ -b "$device1" ] && [ -z "$(mount | grep -E "^$device1")" ] && devdisk=$device1 && break
            done
            [ -b $devdisk ] && break
        fi
        sleep 1s;
    done

    if [ -x "/usr/sbin/mkfs.${disk_format}" ]; then
        devpath="/mnt/disk$i"
        mkdir -p $devpath
        if ! grep -q -F $devpath /etc/fstab; then
            parted -s $devdisk \
                mklabel gpt \
                mkpart primary ${disk_format} 0% 100%
            devpart="$(lsblk -l -p $devdisk | tail -n1 | cut -f1 -d' ')"
            devuuid="$(uuidgen)"
            yes | mkfs.${disk_format} -m 0 -U $devuuid $devpart
            echo "UUID=$devuuid $devpath auto defaults,nofail 0 2" >> /etc/fstab
        fi
        mount -a
        chown ${disk_user}.${disk_group} $devpath
    fi
done

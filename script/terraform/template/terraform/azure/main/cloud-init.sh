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
            printf "n\np\n1\n\n\nw\nq\n" | fdisk $devdisk
            yes | mkfs.${disk_format} -m 0 $devdisk
            devuuid="$(blkid $devdisk | cut -f2 -d' ')"
            echo "$devuuid $devpath auto defaults 0 2" >> /etc/fstab
        fi
        mount -a
        chown ${disk_user}.${disk_group} $devpath
    fi
done

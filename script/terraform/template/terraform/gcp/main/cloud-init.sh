#!/bin/bash

for i in $(seq ${disk_count}); do
    devdisk="${device_root}-$(( i - 1 ))"
    until [ -e $devdisk ]; do sleep 1s; done

    if [ -x "/usr/sbin/mkfs.${disk_format}" ]; then
        devpath="/mnt/disk$i"
        mkdir -p $devpath
        if ! grep -q -F $devdisk /etc/fstab; then
            printf "n\np\n1\n\n\nw\nq\n" | fdisk $devdisk
            yes | mkfs.${disk_format} -m 0 $devdisk
            echo "$devdisk $devpath ${disk_format} defaults 0 2" >> /etc/fstab
        fi
        mount -a
        chown ${disk_user}.${disk_group} $devpath
    fi
done

#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -r /etc/apt/apt.conf.d/20auto-upgrades ]; then
    sed -i -e '/APT::Periodic::Update-Package-Lists/{s/"1"/"0"/}' -e '/APT::Periodic::Unattended-Upgrade/{s/"1"/"0"/}' /etc/apt/apt.conf.d/20auto-upgrades
fi

premounted="$(mount | grep -F ' /mnt ' | cut -f1 -d' ')"
if [ -n "$premounted" ]; then
    sed -i 's|^\([A-Za-z0-9=_/]\+\s\+/mnt\s\+.*\)$|#\1|' /etc/fstab
    umount /mnt
fi

%{ for disk in disks ~}
  while true; do
    device=${disk.device}
    [ -b $device ] && break
    if [ -n "${disk.serial}" ]; then
      device="$(lsblk -l -p -o +SERIAL | grep " disk " | grep -F ${disk.serial} | cut -f1 -d' ')"
      [ -b "$device" ] && break
    else
      for device1 in $(lsblk -l -p | grep " disk " | cut -f1 -d' '); do
        [ -b "$device1" ] && [ -z "$(mount | grep -E "^$device1")" ] && device=$device1 && break
      done
      [ -b "$device" ] && break
    fi
    sleep 1s
  done

  if [ -x "/usr/sbin/mkfs.${disk_format}" ]; then
    mkdir -p ${disk.mount_path}
    if ! grep -q -F " ${disk.mount_path} " /etc/fstab; then
      if [ "$premounted" != "$device" ]; then
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
      else
        echo "$device ${disk.mount_path} auto defaults,nofail 0 2" >> /etc/fstab
      fi
    fi
    mount -a
    chown ${disk.user}.${disk.group} ${disk.mount_path}
  fi
%{ endfor ~}


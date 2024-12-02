#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -r /etc/apt/apt.conf.d/20auto-upgrades ]; then
    sed -i -e '/APT::Periodic::Update-Package-Lists/{s/"1"/"0"/}' -e '/APT::Periodic::Unattended-Upgrade/{s/"1"/"0"/}' /etc/apt/apt.conf.d/20auto-upgrades
fi

%{ for disk in disks ~}
  while true; do
    device=${disk.device}
    [ -b $device ] && break
    sleep 1s
  done

  if [ -x "/usr/sbin/mkfs.${disk_format}" ]; then
    mkdir -p ${disk.mount_path}
    if ! grep -q -F " ${disk.mount_path} " /etc/fstab; then
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
    chown ${disk.user}.${disk.group} ${disk.mount_path}
  fi
%{ endfor ~}


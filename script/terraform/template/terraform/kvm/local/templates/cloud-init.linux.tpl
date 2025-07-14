#cloud-config
# vim: syntax=yaml
hostname: '${host_name}'
write_files:
  - path: /etc/environment
    content: |
      http_proxy="${http_proxy}"
      https_proxy="${https_proxy}"
      no_proxy="${no_proxy}"
    append: true
  - path: /usr/local/bin/map-data-disks.sh
    content: |
      #!/bin/bash -x
      i=0
      for d in /dev/disk/by-id/nvme-eui.*; do
        if [ -e "$d" ] && [[ "$d" =~ ^.*/nvme[-]eui[.][0-9a-z]+$ ]]; then
          ln -nsrf $d /dev/disk/by-label/data_disk_$i
          let i++
        fi
      done
      %{for i,disk in data_disks }
      if [ -e /dev/disk/by-label/data_disk_${i} ]; then
        parted -s /dev/disk/by-label/data_disk_${i} \
          mklabel gpt \
          mkpart primary ${disk.format} 0% 100%
        sync
        devpart="$(lsblk -l -p /dev/disk/by-label/data_disk_${i} | tail -n1 | cut -f1 -d' ')"
        devuuid="$(uuidgen)"
        if [ "${disk.format}" == "xfs" ]; then
          yes | mkfs.${disk.format} -m uuid=$devuuid $devpart
        else
          yes | mkfs.${disk.format} -m 0 -U $devuuid $devpart
        fi
      fi
      %{endfor}
      i=0
      for d in /dev/disk/by-id/nvme-eui.*-part1; do
        if [ -e "$d" ]; then
          ln -nsrf $d /dev/disk/by-label/data_disk_$${i}_p1
          let i++
        fi
      done
    permissions: '0755'
disable_root: true
users:
  - name: ${user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/${user}
    shell: /bin/bash
    ssh_authorized_keys:
    - ${authorized_keys}
disk_setup:
%{for disk in data_disks ~}
  ${disk.device}:
    table_type: gpt
    layout: [100]
    overwrite: true
%{endfor ~}
fs_setup:
%{for i,disk in data_disks ~}
  - label: data_disk_${i}
    device: ${disk.device}
    filesystem: ${disk.format}
    partition: auto
    overwrite: true
%{endfor ~}
mounts:
%{for i,disk in data_disks ~}
%{if strcontains(disk.name,"/dev/nvme") ~}
  - ["/dev/disk/by-label/data_disk_${i}_p1","${disk.path}","auto","defaults,nofail","0","2"]
%{else ~}
  - ["${disk.device}","${disk.path}","auto","defaults,nofail","0","2"]
%{endif ~}
%{endfor ~}
runcmd:
  - /usr/local/bin/map-data-disks.sh
%{for i,disk in data_disks ~}
  - mkdir -p ${disk.path}
%{if strcontains(disk.name,"/dev/nvme") ~}
  - mount /dev/disk/by-label/data_disk_${i}_p1 ${disk.path}
%{else ~}
  - mount /dev/disk/by-label/data_disk_${i} ${disk.path}
%{endif ~}
  - chown -R ${user} ${disk.path}
%{endfor ~}
  - sed -i -e '/APT::Periodic::Update-Package-Lists/{s/"1"/"0"/}' -e '/APT::Periodic::Unattended-Upgrade/{s/"1"/"0"/}' /etc/apt/apt.conf.d/20auto-upgrades || true

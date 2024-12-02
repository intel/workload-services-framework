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
    layout: True
    overwrite: True
%{endfor ~}
fs_setup:
%{for disk in data_disks ~}
  - device: ${disk.device}
    filesystem: ${disk.format}
    partition: 1
%{endfor ~}
mounts:
%{for disk in data_disks ~}
  - ["${disk.device}","${disk.path}","auto","defaults,nofail","0","2"]
%{endfor ~}
runcmd:
%{for disk in data_disks ~}
  - mkdir -p ${disk.path}
  - mount ${disk.device} ${disk.path}
  - chown -R ${user} ${disk.path}
%{endfor ~}
  - sed -i -e '/APT::Periodic::Update-Package-Lists/{s/"1"/"0"/}' -e '/APT::Periodic::Unattended-Upgrade/{s/"1"/"0"/}' /etc/apt/apt.conf.d/20auto-upgrades || true

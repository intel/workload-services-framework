#cloud-config
# vim: syntax=yaml
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
timezone: '${time_zone}'
runcmd:
  - date -s '${date_time}'

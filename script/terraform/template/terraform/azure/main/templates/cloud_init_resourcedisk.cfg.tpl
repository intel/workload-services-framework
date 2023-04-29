#cloud-config
disk_setup:
  ephemeral0:
    table_type: gpt
    layout: true
    overwrite: true
fs_setup:
  - device: ephemeral0.1
    filesystem: ext4
mounts:
  - ["ephemeral0.1", "/mnt/resource"]
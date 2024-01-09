# Nginx Cache Server Setup

This document is a guide for setting up Nginx-DLB benchmark environment, including Hardware platform and Software configuration on storage.

## HW Prerequisites

- Setup 3 servers: one node (client) for client deployment; 2 node for cache server (worker-0) and content server (worker-1) deployment.
- Cache server (worker-0) requires 5 NVMe disks.

## K8S Labels configuaration

Please finish the section, [Storage configuration](setup-nginx-cache.md#storage-configuration), then label the corresponding nodes.

Command examples:

- Label:
  ```shell
  kubectl label node <node name> HAS-SETUP-NVMECACHE=yes
  ```
- Unlabel:
  ```shell
  kubectl label node <node name> HAS-SETUP-NVMECACHE-
  ```

Nginx cache server worker-0:*

- `HAS-SETUP-NGINX-CACHE=yes`

## Storage configuration

This should be done on worker-0.

- Prepare 5 nvme disk for nginx cache server pod. *nvme?* means multiple nvme disk.

  - Check NVMe drives and Partition drives
    ```shell command
    ls /dev/nvme*
    ```

    ```output
    /dev/nvme1    /dev/nvme2    /dev/nvme3    /dev/nvme4    /dev/nvme5
    ```

  - Format drives as ext4 (or xfs):
    ```shell command
    mkfs.ext4 /dev/nvme1n1
    mkfs.ext4 /dev/nvme2n1
    mkfs.ext4 /dev/nvme3n1
    mkfs.ext4 /dev/nvme4n1
    mkfs.ext4 /dev/nvme5n1
    ```

  - Create cache mountpoints and mount to four pairs
    ```shell command
    mkdir /nginx/cache1
    mount -o rw,noatime,seclabel,discard /dev/nvme1n1 /nginx/cache1
    mkdir /nginx/cache2
    mount -o rw,noatime,seclabel,discard /dev/nvme2n1 /nginx/cache2
    mkdir /nginx/cache3
    mount -o rw,noatime,seclabel,discard /dev/nvme3n1 /nginx/cache3
    mkdir /nginx/cache4
    mount -o rw,noatime,seclabel,discard /dev/nvme4n1 /nginx/cache4
    mkdir /nginx/cache5
    mount -o rw,noatime,seclabel,discard /dev/nvme5n1 /nginx/cache5
    ```
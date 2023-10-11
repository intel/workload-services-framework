# CDN Setup

This document is a guide for setting up CDN benchmark environment, including Hardware platform and Software configuration on network, storage and QAT.

## HW Prerequisites

- Setup 2 or 3 servers:

  - 3-node: one client node; 2 CDN servers: worker-1, worker-2.
  - 2-node: one client node; 1 CDN server: worker-1.
- All servers support at least `100G` network bandwidth, e.g. 1x 100G NIC
- Connect all servers through a switch with at least `100G` network capacity.
- CDN server requires 4 NVMe disks, each has at least `1.8T` size capacity. And it's better to support PCIe Gen4 x4 width.
- Please consider NUMA balance for NVMe drive and NIC setup, this is important for performance tests.

  ```mermaid

  flowchart TD;
    subgraph 3-node;
    subgraph Server_cluster;
    worker_1;
    worker_2;
    end

    100G_switch[[100G_switch]]-.-Client_Node;
    100G_switch[[100G_switch]]-.-worker_1;
    100G_switch[[100G_switch]]-.-worker_2;

    end

  ```

  ```mermaid

  flowchart TD;
    subgraph 2-node;
      subgraph Server_cluster;
      worker_1;
      end

    100G_switch[[100G_switch]]-.-Client_Node;
    100G_switch[[100G_switch]]-.-worker_1;
    end

  ```

## OS configuration

- Install Ubuntu 22.04 server-version or latest version on CDN server.
- Check the NVMe driver and NIC driver are all loaded and setup fine.
- Setup network proxies if needed and append server (e.g. 192.168.2.200) and client (e.g. 192.168.2.100) 100G NIC IP to your `no_proxy` on client and server.

## K8S Labels configuaration

Please finish the section [Network configuration](setup-cdn.md#network-configuration), [Storage configuration](setup-cdn.md#storage-configuration), or [QAT hardware configuration](setup-cdn.md#qat-hardware-configuration), then label the corresponding nodes.

Command examples:

- Label:
  ```shell
  kubectl label node node_name HAS-SETUP-NIC-100G=yes
  ```
- Unlabel:
  ```shell
  kubectl label node node_name HAS-SETUP-NIC-100G-
  ```

*CDN server worker-1:*

For ICX,

- `HAS-SETUP-DISK-SPEC-1=yes`
- `HAS-SETUP-NIC-100G=yes`

For SPR,

- `HAS-SETUP-DISK-SPEC-1=yes`
- `HAS-SETUP-NIC-100G=yes`
- `HAS-SETUP-QAT=yes`
- `HAS-SETUP-HUGEPAGE-2048kB-4096=yes`

*CDN server worker-2:*

- `HAS-SETUP-NIC-100G=yes`

## Network configuration

- Specify 100G IP for servers. These are defined in *validate.sh*, please pass the real IP as parameters before testing.

  | client        | worker-1      | worker-2      |
  | --------------- | --------------- | --------------- |
  | 192.168.2.100 | 192.168.2.200 | 192.168.2.201 |

  - modify in `validate.sh`
    ```shell
    NICIP_W1=${NICIP_W1:-192.168.2.200}
    NICIP_W2=${NICIP_W2:-192.168.2.201}
    NICIP_W1="real IP of worker-1"
    NICIP_W2="real IP of worker-2"
    ```
  - or pass with `ctest.sh`
    ```shell
    ./ctest.sh --set NICIP_W1="real IP" NICIP_W2="real IP" ...
    ```

- Test the network speed after setting up

  - On worker-1
    ```shell
    iperf -s
    ```
  - On client node
    ```shell
    iperf -c 192.168.2.200 -P 4
    ```

## Storage configuration

This should be done on worker-1.

- Prepare cache disk for cache-nginx pod. *nvme?n1* means repeat 4 times for 4 disks.

  - Check NVMe drives and Partition drives
    ```shell
    ls /dev/nvme*
    ```

    ```text
    /dev/nvme?n1
    ```

  - Create a primary partition `/dev/nvme?n1p1`
    - If disk is lower than 2 TB
      ```shell
      sudo fdisk /dev/nvme?n1
      ```
    - If disk size is higher than 2 TB
      ```shell
      sudo parted /dev/nvme?n1
      ```

  - Change drive attributes
    ```shell
    sudo chown nobody /dev/nvme?n1p1
    ```

  - Format drives as ext4 (or xfs):
    ```shell
    mkfs.ext4 -F /dev/nvme?n1p1
    ```

  - Create cache mountpoints and mount to four pairs
    ```shell
    mkdir /mnt/disk1 /mnt/disk2 /mnt/disk3 /mnt/disk4
    mount -o defaults,noatime,nodiratime /dev/nvme?n1p1 /mnt/disk?
    ```

  - Add below content into `/etc/fstab` to auto-mount after reboot
    ```shell
    /dev/nvme?n1p1 /mnt/disk? ext4 rw,noatime,seclabel,discard 0 0
    ```
  - Modify storage IO schedule method from default `mq-deadline` to `none` on
    ```shell
    echo none > /sys/block/nvme?n1/queue/scheduler
    ```

  - Check the partition status
    ```shell
    sudo fdisk -l /dev/nvme*n*
    ```

## QAT hardware configuration

Set up QAT Hardware for SPR worker-1, please refer to [`setup-qat-in-tree`](setup-qat-in-tree.md).

## Monitor runtime performance

- Use `sar` to monitor runtime network interface performance

  ```shell
    sar -n DEV 3 -h   # probe every 3s
  ```

- Use `iostat` to monitor drive IO performance.

  ```shell
    iostat 5    # probe every 3s
  ```

## Others

- Install Intel E810-C CVL Ethernet Adaptor Driver

  - Confirm the NIC model, pls run below command line:
    ```shell
    lspci | grep Eth
    17:00.0 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GBASE-T (rev 02)
    17:00.1 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GBASE-T (rev 02)
    4b:00.0 Ethernet controller: Intel Corporation Ethernet Controller E810-C for QSFP (rev 02)
    4b:00.1 Ethernet controller: Intel Corporation Ethernet Controller E810-C for QSFP (rev 02)
    ```
    In this environment, Intel 100G E810-C NIC is used for CDN NGINX testing.
  - Install the kernel development package

    To compile the driver on some kernel/arch combinations, you may need to install the kernel development package which has the same version with kernel. you can firstly try to install with:
    ```shell
    sudo apt-get install linux-headers-$(uname -r)
    ```
  - Intel E810 series devices Ethernet Adapter Driver Installation
    - Download the latest E810 series devices firmware update from https://www.intel.com/content/www/us/en/download/19626/non-volatile-memory-nvm-update-utility-for-intel-ethernet-network-adapters-e810-series-linux.html.
    - Download the latest E810 series devices driver from https://www.intel.com/content/www/us/en/download/19630/intel-network-adapter-driver-for-e810-series-devices-under-linux.html.
    - Build and install the NIC driver:
      ```shell
      tar xvfz ice-1.6.7.tar.gz
      cd ice-1.6.7/src
      make clean
      make
      make install
      rmmod ice; modprobe ice
      ```

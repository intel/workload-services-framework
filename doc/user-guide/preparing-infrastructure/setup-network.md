# Setup network

For network workload, the test environment must be prepared in advance.  

Install high-speed network NIC and link multiple workers together using either a high-speed switch or point-to-point cross-link cables. The network interface can be either a physical interface or a logical bond of multiple physical interfaces.

For example, at least two Ice Lake (or Sapphire Rapids) Linux hosts running CentOS Stream. On each Linux Host, you shall install one Intel E810-CQDA2 or E810-2CQDA2 100GE NIC adaptor (each adaptor has two 100GE ports) under CPU0 IIO root port PCIe bus (DO NOT install the 100GE NIC adaptor under PCH PCIe bus).

## Network Setup

1. Use two 100GE copper(or optical) cables to connect those 100GE ports, connection method: 
    ``` 
    Host0 100GE physical port0 <-> Host1 100GE physical port0;  (100GE connection 0 between two Linux hosts)  
    Host0 100GE physical port1 <-> Host1 100GE physical port1;  (100GE connection 1 between two Linux hosts)  
    ```
    > Note: Make sure those 100GE ports is link up from NIC ports LED green light after machine power on again

2. Make sure you Linux Hosts installed Linux kernel 100GE driver package "ice" for E810 adaptor: 
    ``` 
    modprobe ice
    ```  
    Use Linux command to make sure ice driver/firmware version and 100GE ports link up Status/Duplex/Speed is 100GE full duplex link up.  
    ``` 
    ethtool ethX
    ethtool -i ethX
    ``` 
    * ethX is the interface name of each 100GE port in Linux host `ifconfig` output.  
    * you can use Linux kernel in-tree ice driver package. Just FYI: latest ice driver package download: https://sourceforge.net/projects/e1000/files/ice%20stable/  

3. Use ifconfig command to config correct IP address with two different subnets(eg, 192.168.8.x and 192.168.9.x) for two 100GE connections, ping each other Linux Host to make sure those 100GE connections works fine;  
For Example, you can configure IP address like this:  
Host0 100GE physical port0(192.168.8.88) <-> Host1 100GE physical port0(192.168.8.99).  
Host0 100GE physical port1(192.168.9.88) <-> Host1 100GE physical port1(192.168.9.99). 
    - Host0
    ```
    sudo ifconfig <port0-name> 192.168.8.88 netmask 255.255.255.0 up
    sudo ifconfig <port1-name> 192.168.9.88 netmask 255.255.255.0 up
    ```
    - Host1
    ```
    sudo ifconfig <port0-name> 192.168.8.99 netmask 255.255.255.0 up
    sudo ifconfig <port1-name> 192.168.9.99 netmask 255.255.255.0 up
    ```
    - Host0
    ```
    ping 192.168.8.99
    ping 192.168.9.99
    ```

4. On each Linux host, use command to find out two E810 devices PCIe bus:device:function numbers, bind E810 PCIe devices to DPDK will use this PCIe bus:device:function number.  
    ```
    lspci | grep Eth | grep E810
    ```

5. On each Linux host, install currently running kernel version kernel-devel package, then you can compile kernel modules .ko;
    ```
    yum install kernel-devel
    ```
    * make sure installed kernel-devel version equals `uname -r` version.

6. On each Linux host, we now suggest to bind NIC port to vfio-pci because igb_uio is not supported in newest OS.

    To use vfio-pci we need to add intel_iommu=on iommu=pt to the Linux Boot Command line.
    ```
    sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on iommu=pt"
    sudo reboot
    ```  
    Also enable Intel vt-d in bios:  
    >EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable  

    Command to check Virtualization Technology and IOMMU enable:  
    ```    
    dmesg | grep -E "DMAR|IOMMU"  
    ```
    Then plugin vfio-pci module:  
    ```
    sudo modprobe vfio-pci
    ```
7. On each Linux host, use command to set 100GE ports as ifconfig down state. 
    ```
    ifconfig <port-name> down
    ```  
    * if E810 ports is ifconfig up state, it cannot bind to DPDK vfio-pci.  

8. On each Linux Host, download DPDK21.11.tar.xz, decompress it, use dpdk-devbind.py to bind 100GE ports to DPDK vfio-pci
    ```
    wget http://fast.dpdk.org/rel/dpdk-21.11.tar.xz
    tar xf dpdk-21.11.tar.xz
    cd dpdk-stable-21.11/usertools
    ./dpdk-devbind.py --status
    ./dpdk-devbind.py --bind=vfio-pci bus:dev:func bus:dev:func
    ./dpdk-devbind.py --status 
    ```
    - >Note: if your dpdk-devbind.py cannot running, run: 
    ```
    yum install -y numactl libfdt pciutils which python3
    ``` 
    - >Note: if you want to bind 100GE port to kernel driver "ice" again run:
    ```
    ./dpdk-devbind.py --bind=ice bus:dev:func bus:dev:func
    ```

9. Use these commands to add labels to K8S nodes.

    Currently workloads l3fwd/vppfib/ngfw/ovs-dpdk/pktgen need this label to schedule.

    It indicates that the two 100GE ports have been bound to DPDK vfio-pci driver on the Linux host correctly. 
    ``` 
    kubectl label nodes nodeX HAS-SETUP-DPDK=yes --overwrite
    kubectl label nodes nodeY HAS-SETUP-DPDK=yes --overwrite
    ```

10. On Linux grub boot up command line, you need to setup huge page numbers >= 2048.  
    ```
    grubby --update-kernel=DEFAULT --args="hugepages=2048"
    reboot
    ```
    The workload requests 2048 2MB hugepages. See [Hugepage Setup][Hugepage Setup] for setup instructions. 

    After properly setup two Linux hosts 2MB hugepages, use these commands to make K8S two nodes label, currently l3fwd/pktgen k8s scheduling need this label. 
    ``` 
    kubectl label nodes nodeX HAS-SETUP-HUGEPAGE-2048kB-2048=yes --overwrite  
    kubectl label nodes nodeY HAS-SETUP-HUGEPAGE-2048kB-2048=yes --overwrite
    ```

11. Install K8S/Docker environment, configure one Linux host as k8s master and node, another Linux host as k8s node.  

    This workload can run with K8S backend; this workload cannot run with single host Docker backend;

12. Create configuration file named `network_env.conf` in the etc directory. This file contains 100G port or device information. The context should follow the following format: `/etc/network_env.conf`
    ``` 
    dpdk_port1=0000:38:00.0    
    dpdk_port2=0000:38:00.1  
    dsa_dev1=0000:6a:01.0  
    dsa_dev2=0000:6f:01.0  
    dpdk_port1_srcmac_l3fwd=0xb4,0x96,0x91,0xb2,0xa6,0x48  
    dpdk_port2_srcmac_l3fwd=0xb4,0x96,0x91,0xb2,0xa6,0x49  
    dpdk_port1_destmac_l3fwd=0xb4,0x96,0x91,0xc3,0x85,0xd8  
    dpdk_port1_destmac_l3fwd_tx=b4:96:91:c3:85:d8  
    dpdk_port2_destmac_l3fwd=0xb4,0x96,0x91,0xc3,0x85,0xd9  
    dpdk_port2_destmac_l3fwd_tx=b4:96:91:c3:85:d9  
    dpdk_port_mac1=0xb4,0x96,0x91,0xb2,0xa5,0x10  
    dpdk_port_mac2=0xb4,0x96,0x91,0xb2,0xa5,0x11  
    neigh_port_mac1=0xb4,0x96,0x91,0x9b,0x79,0x38  
    neigh_port_mac2=0xb4,0x96,0x91,0x9b,0x79,0x39  
    ```

    * dpdk_port[1-9] means 100G port pci number.This port is bound to vfio_pci and used by dpdk. You can use command `lspci | grep Eth | grep E810` to get pci number.

    * dsa_dev[1-9] means DSA device number.For Intel® DSA devices, they are currently (at time of writing) appearing as devices with type “0b25”, due to the absence of pci-id database entries for them at this point. This device is bound to vfio_pci and used by dpdk. You can use command `lspci | grep 0b25` to get dsa device number.

    * dpdk_port_mac[1-9]: MAC address of NIC port with format as example 0xb4,0x96,0x91,0xb2,0xa6,0xd8.

    * neigh_port_mac[1-9]: MAC address of NIC port which connected with dpdk_port on another test machine.  

    * dpdk_port[1-9]_srcmac_l3fwd: MAC address of NIC in this host port with format as example 0xb4,0x96,0x91,0xb2,0xa6,0x48.

    * dpdk_port[1-9]_destmac_l3fwd: MAC address of NIC port which connected with dpdk_port on another test machine.

    * dpdk_port[1-9]_destmac_l3fwd_tx: MAC address of NIC port which connected with dpdk_port on another test machine. Format should be b4:96:91:c3:85:d8


A workload can request network as follows:
- `HAS-SETUP-NETWORK-SPEC-1`: The worker node must have a set of network, whose specification, `netwrok_spec_1`, is specified in the `terraform` configuration files.  


### Node Labels:

Label the worker nodes with the following node labels:  
- `HAS-SETUP-NIC-25G=yes`: Optional. 
- `HAS-SETUP-NIC-40G=yes`: Optional.  
- `HAS-SETUP-NIC-100G=yes`: Optional.
- `HAS-SETUP-DPDK=yes`: Required. 
- `HAS-SETUP-HUGEPAGE-2048kB-2048=yes`: Required. 
- `HAS-SETUP-NETWORK-SPEC-1=yes`: The worker node is equipped with the network described in `network_spec_1`.  

## See Also:

- [DPDK website][DPDK website]
- [VPP website][VPP website]
- [Pktgen website][Pktgen website]

[Hugepage Setup]: setup-hugepage.md
[DPDK website]: https://www.dpdk.org
[VPP website]: https://fd.io/
[Pktgen website]: http://git.dpdk.org/apps/pktgen-dpdk/

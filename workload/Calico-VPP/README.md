>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

[Calico VPP](https://projectcalico.docs.tigera.io/getting-started/kubernetes/vpp/getting-started) is one of Calico dataplanes, which takes advantages of VPP to scale higher throughput in K8S cloud native environment. It's easily extensible using VPP plugins such as DPDK, IPSec, etc. Calico VPP provides memif userspace packet interfaces to the K8S pods and exposes the VPP Host Stack to run optimized L4+ applications in K8S pods. This testing is based on Calico VPP version 3.23.0.

Calico VPP supports memif interface to improve packets transmission performance between memif master and slave, we call this kind of memif interface is software(SW) memif since it uses CPU to copy memory data from memif master to slave. If DSA is enabled on memif interface, we call it's DSA memif because it will use DSA instead of CPU to copy memory data. So, there are 2 typical testing scenarios, SW memif interface testing , DSA memif interface testing.

### Test cases parameters:

```
+-------------------------------+      +-----------------------------------+
|  +————————————+   +————————+  |      |  +——————————+       +——————————+  |        
|  | Calico-VPP |   |  TRex  |  |      |  |Calico-VPP| memif |VPP-L3FWD |  | 
|  |       	|   |        |  |      |  |          |<— — —>|          |  |
|  |            |   |        |  |      |  | +——————+ |       |          |  |
|  |            |   |        |  |      |  | |  DSA | |       |          |  |
|  |	        |   |        |	|      |  | +——————+ |       |          |  |
|  +————————————+   +————————+  |      |  +——————————+       +——————————+  |		 
|        ^               ^      |      |        ^			   |
|	DPDK            DPDK    |      |       DPDK              	   |
|	 v  	         v      |      |        v			   |
|      Port A          port B   |      |      port A  	                   |
+------------------------- -----+      +-----------------------------------+
        ^                 ^                   ^    ^
        |	          |                   |    |
        |                 |    +— — — — — —+  |    |
 	|                 - -->|  SWITCH   |<--    |
 	- - - - - - - - - - -->|           |<-- - -               
     	                       +— — — — — —+	
```

Mandatory parameters (in validate.sh):

1. `TREX_PCI_ID_1` is one of TREX send packets NIC's port;
2. `DEST_MAC_1` must be Calico-VPP master node's NIC ports;
3.  `TREX_MAC_ADDRESS`  is `TREX_PCI_ID_1` 's MAC address.

Optional parameters:

1. `MTU`: Specify MTU, value can be 1500 or 9000. Default is 1500;
2. `CORE_SIZE`: Specify how many CPU cores will be used for the testing. Default is 1;
3. `ENABLE_DSA` : Specify testing mode, value can be `true`, `false` for DSA memif, SW memif testing. Default is true;
4. `VPP_CORE_START`: Specify start CPU cores used for Calico VPP. Default is 10;
5. `MASTER_THREAD_ID`: Refers to the identifier of the main control thread in TRex, specify in trex_cfg.yaml. Default is 20;
6. `LATENCY_THREAD_ID`: Refers to the identifier of the thread dedicated to measuring network traffic latency, specify in trex_cfg.yaml. Default is 21;
7. `TREX_THREADS`:  Refers to the cores used to generate and process network traffic, specify in trex_cfg.yaml. Default is "22.23.24.25.26.27.28.29".
8. `TREX_PACKET_SIZE` : Specify packet size for TRex generate network traffic, like: 64, 128, 256, 512, 1024 (bytes),etc. Default is 1024;
9. `TREX_DURATION`: Specify TRex test duration. Default is 30s;
10. `TREX_SOURCE_IP`: Specify TRex source IP for generate network traffic. Default is 10.10.10.10;
11. `TREX_STREAM_NUM`: Specify TRex stream number. Default is 1;
12. `TREX_CORE_NUM`: Specify core number for TRex generate and process network traffic. Default is 8;
### Docker Image

The workload contains 5 images: `trex`, `calicovpp_dsa_agent`, `calicovpp_dsa_vpp`, `calicovpp_dsa_build_base`, `calicovpp_l3fwd`.

- `trex`: Trex will generate and send packets to ports,  and receive packets from those ports, and do ports statistics(simulated a hardware packet generator);

- `calicovpp_dsa_build_base`: The base image of  `calicovpp_dsa_agent`  and `calicovpp_dsa_vpp` for dsa enable.

- `calicovpp_dsa_agent`:  Responsible for all the runtime configuration of VPP for Calico;

- `calicovpp_dsa_vpp`: This image contain VPP Manager which is a very light process responsible for the bootstrap of VPP, including uplink interface addressing and routing configuration. 

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs. The following KPIs are defined:

- **`TX (Mpps)`**: TX stands for transmitting packets.
- **`RX (Mpps)`**: RX stands for receiving packets.
- **`TX_L1 (Gbps)`**: represents the physical layer transmission.
- **`RX_L1 (Gbps)`**: *primary KPI*, represents the physical layer reception.

### System Setup
To run this workload, make sure unhold kubeadm and kubectl and kubelet. Please implement this command `sudo apt-mark unhold kubeadm kubectl kubelet` to unhlod. And Make sure to setup network first. Please See [Network Setup](../../doc/user-guide/preparing-infrastructure/setup-network.md) for network setup instructions.

Configure 16GB hugepages (like this):
```
sudo grubby --update-kernel=DEFAULT --args="default_hugepagesz=1G hugepagesz=1G hugepages=16 intel_iommu=on iommu=on isolcpus=28-55,140-167,84-111,196-223"
```

See [Cluster Config](../../doc/developer-guide/component-design/cluster-config.md) for K8S/Cumulus validation environment setup instructions.
This workload validation needs the two K8S nodes both have label:
```
  HAS-SETUP-NIC-100G=yes 
  HAS-SETUP-MODULE-VFIO-PCI=yes  
  HAS-SETUP-HUGEPAGE-1048576kB-16=yes
```
Config BIOS with Intel Hyper-Threading : Enable

### Network Configuration

To Run this workload, make sure two 100G network cards on each server. Create configuration file named `network_env.conf` in the etc directory. This file contains 100G port or device information. The context should follow the following format: /etc/network_env.conf 
``` 
dpdk_port1=0000:98:00.0
dpdk_port2=0000:99:00.0
dpdk_port1_srcmac=0xb4,0x96,0x91,0xb2,0x34,0xb0
dpdk_port2_srcmac=0xb4,0x96,0x91,0xb2,0x25,0x00
dpdk_port1_destmac=0xb4,0x96,0x91,0xc3,0x32,0x60
dpdk_port2_destmac=0xb4,0x96,0x91,0xc3,0x33,0x00
```

* dpdk_port[1-9] means 100G port pci number.This port is binded to vfio_pci and used by dpdk. You can use command "lspci | grep Eth | grep E810" to get pci number.
* dpdk_port[1-9]_srcmac_l3fwd: MAC address of NIC in this host port with format as example 0xb4,0x96,0x91,0xb2,0xa6,0x48.
* dpdk_port[1-9]_destmac_l3fwd: MAC address of NIC port which connected with dpdk_port on another test machine.

### Performance BKM

- **System** ( In this sample, the NIC used by the cluster is on NUMA node 1, NUMA node0 CPUs: 0-63,128-191; NUMA node1 CPUs: 64-127,192-255 )

  - 1G hugepages: 16
  - isolcpus: 0-31,64-95 ( 0-31  used for TRex threads, 64-95 used for Calico VPP and L3FWD.  CPU cores on NUMA 1 for benchmark) 
  - intel_iommu: ON
  - Intel Turbo Boost: Enabled
  - Automatic NUMA Balancing: Enabled
  - network topology: two nodes connected switch


- **BIOS**
  
  | BIOS setting                     | SPR         |
  | -------------------------------- | ----------- |
  | Hyper-Threading                  | Enable      | 
  | CPU power and performance policy | Performance | 
  | turbo boost technology           | Enabled     | 
  | processor C6                     | Enabled     | 
  | C1E                              | Enabled     | 
  | Package C State                  | C0/C1 state | 
  | Hardware P-States                | Native Mode | 
  | Intel VT for directed I/O        | Enabled     | 

### See Also

- [DPDK website](https://www.dpdk.org)
- [Calico-VPP website](https://github.com/projectcalico/vpp-dataplane)
- [TREX website](https://trex-tgn.cisco.com/)
>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

SPDK provides a set of tools and libraries for writing high performance, scalable, user-mode storage applications.it also support the NVMe/TCP transport function.

The NVMe/TCP enables efficient end-to-end NVMe operations between NVMe-oF host(s) and NVMe-oF controller devices interconnected by any standard IP network with excellent performance and latency characteristics. This allows large-scale data centers to utilize their existing ubiquitous Ethernet infrastructure with multi-layered switch topologies and traditional Ethernet network adapters. NVMe/TCP is designed to layer over existing software based TCP transport implementations as well as future hardware accelerated implementations.

Intel® DSA is a high-performance data copy and transformation accelerator that is integrated in future Intel® processors including SPR, targeted for optimizing streaming data movement and transformation operations common with applications for high-performance storage, networking, persistent memory, and various data processing applications, like `copy` `crc32c` `compare` `dualcast` `copy_crc32c` `fill` `compress` `decompress` calculation. And in current workload,it's used for calculate the NVMe data PDU digest which is crc32 calculation,this can help to offload the calculation from CPU.

In this workload, we will leverage SPDK NVMe/TCP as a target and leverage Linux kernel NVMe/TCP as Initiator for benchmark.The Initiator will build connection with the Target and get block device info through NVMe over tcp, then mount an NVMe drives in Initiator side for test with fio.
According to the NVMe-over-tcp protocol, if we enable the PDU digest when building connection between Initiator(host) and Target, the data transport between the two ends will be calculated with CRC, called as digest data(including Header digest and Data digest) alongside with the raw data to transfer. it generally happens at both sender point and receiver point which according to data R/W operation. And DSA can help to accelerate the CRC calculation instead of by CPU in this case


### Test Case
This SPDK NVMe over TCP stack support the block function for the Initiator which provides serveral test cases with the following configuration parameters:
- **Cases type**: One of the major storage function for Edge Ceph, provide block device to client.
  - `withDSA`: Test cases with Intel DSA feature enabled.
  - `noDSA`: Test cases without Intel DSA feature, digest is caculated with CPU.
- **IO Operations**: Common IO operation for storage functions, including:
  - `sequential_read`: Test the sequential read performance.
  - `sequential_write`: Test the IO sequential write performance.
  - `sequential_mixedrw`: Test the IO sequential Mixed Read/Write performance with R:W ratio.
  - `random_read`: Test the random IO read operation performance.
  - `random_write`: Test the random IO write operation performance.
  - `random_mixedrw`: Test the IO random Mixed Read/Write performance with R:W ratio.
- **MISC**: This is optional parameter, specify `gated` or `pkm`.
  - `gated` represents running the workload with simple and quick case.
  - `pkm` represents test case with Post-Si performance analysis.

##### More Parameters
Each test case accepts configurable parameters like `TEST_BLOCK_SIZE`, `TEST_IO_DEPTH`, `TEST_DATASET_SIZE` ,`TEST_IO_THREADS`  in [validate.sh](validate.sh). More details as below.
- **Workload**
  - `TEST_DURATION`: Define the test runtime duration.
  - `TEST_BLOCK_SIZE`: Block size for each operation in IO test.
  - `TEST_IO_THREADS`: Test thread count for block io test.
  - `TEST_DATASET_SIZE`: Total data size for block io test with fio.
  - `TEST_IO_DEPTH`: IO count in each IO queue when test the block IO with fio.
  - `TEST_IO_ENGINE`: IO engine for fio test tool, default is `libaio`.
  - `TEST_RAMP_TIME`: The warm up time for FIO benchmark.
  - `TEST_JOBS_NUM`: The Job count for fio process run, it's thread count if thread mode enable.
  - `RWMIX_READ`: The Ratio for read operation in Mixed R/W operation, default is `70%`
  - `RWMIX_WRITE`: The Ratio for write operation in Mixed R/W operation, default is `30%`
- **SPDK process**
  - `SPDK_PRO_CPUMASK`: Used for define the SPDK process CPU usage MASK, default is `0x3F`
  - `SPDK_PRO_CPUCORE`: Cpu core count will be used for SPDK process, default is `6`
  - `SPDK_HUGEMEM`: For spdk process Hugepage allocation, default is `8192` MiB
  - `BDEV_TYPE`: memory bdev or NVMe bdev for test, support `mem`,`null` and `drive`
  - `NVMeF_NS`: Define the NVMe over fabric namespace.
  - `NVMeF_NSID`: Define the NS ID, default is `1`
  - `NVMeF_SUBSYS_SN`: Define NVMe subsystem Serial Number, `SPDKTGT001` is hardcode for S/N

- **NVMe/TCP**
  - `TGT_TYPE`: Target type, current is nvme over tcp, support `tcp`, don't support `rdma`
  - `TGT_ADDR`: Define the nvme-over-tcp tagert address, for TCP it's IP address.
  - `TGT_SERVICE_ID`: # for TCP, it's network IP PORT.
  - `TGT_NQN`: Target nqn ID/name for discovery and connection, e.g. `nqn.2023-03.io.spdk:cnode1`
  - `ENABLE_DIGEST`: Enable or not diable TCP transport digest
  - `TP_IO_UNIT_SIZE`: IO_UNIT_SIZE for create nvme over fabric transport, I/O unit size (bytes), default is `8192`

- **IA DSA config**
  - `ENABLE_DSA`: Enable or disable (`0`/`1`) DSA hero feature for IA paltform.
- **Other config**
  - `DEBUG_MODE`: Used for developer debug during development, more details refer to [validate.sh](validate.sh).

### System Requirements
Generally, we need 2 node for this workload benchmark: Target node and Initiator node connected with high-speed network.
Please pay attention to the `TGT_ADDR` for the Target node, it's the IP address for `tcp` type, user can set the Target node IP with `192.168.88.100` or re-config the parameter according to the NIC IP.
- For Target node,
  - `DSA`: please enable Intel DSA feature, which used for digest offload. See [DSA Setup](../../doc/user-guide/preparing-infrastructure/setup-dsa.md) for host setup instructions.
  - `NVMe drive`: there should be at least 1 NVMe drive.
  - `Other driver`: load `vfio-pci` or `uio_pci_generic` driver module
  - `Huge page`: Please reserver 8192MiB Hugepage for 2M hugepage size.
- For Initiator node, it's needed to enable `nvme-core` and `nvme-tcp` driver module.
  ```
  Check the driver module loaded or not: "lsmod |grep nvme".
  If not loaded, then load module with CMD: "sudo modprobe nvme_core" , "sudo modprobe nvme_tcp"
  ```
### Node Labels:
- Label the `Target node` with the following node labels:
  - `HAS-SETUP-DSA=yes`
  - `HAS-SETUP-MODULE-VFIO-PCI=yes`
  - `HAS-SETUP-HUGEPAGE-2048kB-4096=yes`
  - `HAS-SETUP-DISK-SPEC-1=yes`
  - `HAS-SETUP-NETWORK-SPEC-1=yes`
- Label the `Initiator node` with the following node labels:
  - `HAS-SETUP-NVMETCP=yes`
  - `HAS-SETUP-NETWORK-SPEC-1=yes`

### Docker Image

### Kubernetes run manually
User can run the workload manually, but it's more perfer to run in SF following the [SF-Guide](../../README.md#evaluate-workload). And please make sure the docker image is ready before kubernetes running.

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs,

### Performance BKM


### Index Info
- Name: `SPDK-NVMe-o-TCP`
- Category: `DataServices`
- Platform: `SPR`
- Keywords: `IO` , `DSA` , `SPDK`, `NVMe-Over-TCP`


### See Also
- [SPDK homepage](https://spdk.io)
- [SPDK on Github](https://github.com/spdk/spdk)
- [SPDK NVMe over TCP](https://spdk.io/doc/nvmf.html#:~:text=The%20SPDK%20NVMe%20over%20Fabrics,be%20exported%20over%20different%20transports)
- [FIO parameters detail](https://fio.readthedocs.io/en/latest/fio_doc.html)
- [Intel DSA accelerator](https://01.org/blogs/2019/introducing-intel-data-streaming-accelerator)
- [NVMe over TCP protocol ](https://nvmexpress.org/welcome-nvme-tcp-to-the-nvme-of-family-of-transports/#:~:text=NVMe%2FTCP%20is%20designed%20to,Linux%20Kernel%20and%20SPDK%20environments.)
- [Introduction for SPDK NVMe over TCP with DSA](https://mp.weixin.qq.com/s?__biz=MzI3NDA4ODY4MA==&mid=2653338982&idx=1&sn=1099775c59222bdba62a7a4b1b73b4cb&chksm=f0cb4ae1c7bcc3f746648fbb94382d5cc295422ab027a29357ebe71c4ce109080a1241ad0fee&mpshare=1&scene=1&srcid=12131Lt8FkpTFoACPpRIHrVY&sharer_sharetime=1670896951340&sharer_shareid=16362cd686fb4155d775401692935830&exportkey=n_ChQIAhIQ3dXgDInc52mY5fH3ujTVwhKZAgIE97dBBAEAAAAAAHU3MiYy2UEAAAAOpnltbLcz9gKNyK89dVj01MyEkeLGQCDW7RU0wcXWxq%2Fwwbx%2B1REWT2bQGtxaoHGIP5V%2B6j2jGLQXieaSIsFE2CFEOVFp6MFg7r7X85Cq8ueaalrA3PTtEIKaCalLmJSK%2B%2Bt2xbmXPL9IrSLhiiW2nlhIN5gAj0D%2FeBeldocxEJx%2FiAN30c%2F6AeHVZLpkMytiNb3FqrHmqx9cL%2FnGth1h0pAIvHX451FV1luyDCKbLMQF6c8WbWhJ4dXxx6oFzWtf4ktO%2FenY%2BM9klXamHFhZp5ULL19CgXyuLiMhWnsTPoCza0mL9R%2BOFy%2FBDREOOzrK9VnF5duCffy9p5jYDGYORd0o&acctmode=0&pass_ticket=X3rIA7DhA0Qn%2FAJfhiHkt%2FatLl8TSGQitORh34QjySK1ySy%2BvVvEI1Km%2FufwCUXJMOLA%2BDcVVm6xNTevR4b82g%3D%3D&wx_header=0#rd)

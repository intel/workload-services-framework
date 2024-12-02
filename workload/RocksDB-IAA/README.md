>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
## Index
- [Introduction](#Introduction)
- [Quick Start](#quick-start)
- [Test Case](#test-case)
- [Test Parameter](#test-parameters)
- [KPI](#kpi)
- [Docker image](#docker-image)
- [Index info](#index-info)

## Introduction

RocksDB is developed and maintained by Facebook Database Engineering Team. The Intel® In-Memory Analytics Accelerator (IAA) plugin for RocksDB provides accelerated compression/decompression in RocksDB using IAA and QPL (Query Processing Library). It has a number of tests that are available to be run.

## Quick Start
Please follow steps to run the benchmark quickly.
#### Prerequisite: 
   + Set up data disk(only required when running on BM. WSF will automatically setup disk on cloud)

      Data disk should be mounted to `/mnt/disk*` and NVME drive is recommended for optimal DB performance. 
      
      The number of disk should be related to number of cpu's used by the db and platform. You may need to increase disk number if there are IO bottlebeck.
      
      If you are running with 2 disks, the disks should be mounted to `/mnt/disk1` and `/mnt/disk2`. Below is the script for reference to setup `/mnt/disk1` from a raw disk:
      ```shell
      # set device based on your own environment
      device="/dev/nvme0n1"
      # set partition based on your own environment
      partition="/dev/nvme0n1p1"
      mntDir="/mnt/disk1"

      sudo yum update -y
      sudo yum install parted -y
      sudo parted $device mklabel gpt
      sudo parted -a opt $device mkpart primary xfs 0% 100%

      sudo mkdir -p $mntDir
      sudo mount -o defaults $partition $mntDir
      ```
      If there is already a file system, just to make sure the disk mounted at `/mnt/disk1`.
   + Set up IAA device (required for using iaa compressor testcases)

      The configuration of the IAA device has been done automatically in workload, in order to support the use of the IAA devices in the container but there are still some work to be performed manually.

      First, you need to detect whether the node have IAA devices. below is the script for reference:
      ``` shell
      [ $(lspci -d:0cfe | wc -l) -gt 0 ] && echo "This host has an IAA device" || echo "This host does not own an IAA device"
      ```

      Then you need to change the BIOS configuration as follows.
      ```
      EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
      EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
      ```
      The VT-d must be enabled from the kernel command line. If you are using ubuntu system, please adapt the following command line by yourself.
      ```
      sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
      sudo reboot
      ```
      Additionally, the operating system must meet the following requirements:
      ```
      Linux kernel version 5.18 or later is required for using the first generation of Intel® In-Memory Analytics Accelerator (Intel® IAA).

      Linux kernel version 6.3 or later is required for using the second generation of Intel® IAA.
      ```

#### How run
Please refer to [`Quick Start`](../../README.md) and replace `-DBENCHMARK=mlc` to `-DBENCHMARK=RocksDB-IAA` at running cmake:
```shell
cmake -DPLATFORM=SPR -DBENCHMARK=RocksDB-IAA ..
```

## Test Case
Below are the list of testcase(s) for database.
```shell
Test  #1: test_static_db_bench_rocksdbiaa_iaa_readrandom_pkm
Test  #2: test_static_db_bench_rocksdbiaa_zstd_readrandom_pkm
Test  #3: test_static_db_bench_rocksdbiaa_zlib_readrandom_pkm
Test  #4: test_static_db_bench_rocksdbiaa_lz4_readrandom_pkm
Test  #5: test_static_db_bench_rocksdbiaa_none_readrandom_pkm
Test  #6: test_static_db_bench_rocksdbiaa_iaa_readrandomwriterandom_pkm
Test  #7: test_static_db_bench_rocksdbiaa_zstd_readrandomwriterandom_pkm
Test  #8: test_static_db_bench_rocksdbiaa_zlib_readrandomwriterandom_pkm
Test  #9: test_static_db_bench_rocksdbiaa_lz4_readrandomwriterandom_pkm
Test #10: test_static_db_bench_rocksdbiaa_none_readrandomwriterandom_pkm
Test #11: test_static_db_bench_rocksdbiaa_zstd_readrandom_gated
```
### Compressor/decompressor
- ```iaa```  means the use of Intel® In-Memory Analytics Accelerator (Intel® IAA) as a compressor/decompressor.
- ```zstd``` means the use of [zstd](https://github.com/facebook/zstd) as a compressor/decompressor.
- ```zlib``` means the use of zlib as a compressor/decompressor.
- ```lz4```  means the use of lz4 as a compressor/decompressor.
- ```none``` means no compressor is used.

### Benchmarks
- ```readrandom``` read in random order.
- ```readrandomwriterandom``` read & write in random order.

## Test Parameters
Below are the parameters REQUIRED for this workload, you need to specify these parameters using `./ctest.sh --set`:

1. KEY_SIZE: (size of each key) type: int32. Support key size: `4`, `16`. default: `16`.
2. VALUE_SIZE: (Size of each value in fixed distribution) type: int32. Support value size: `32`, `256`. default: `32`.
3. BLOCK_SIZE: (Number of bytes in a block.) type: int32 Support block size: `4`, `8`, `16`. default: `16`. Note unit is K.
4. DB_CPU_LIMIT: (Test using vCPUs/socket.) type: int32 default: `8`.
5. NUM_SOCKETS: (Test using socket.) type: int32 Support num socket(s): `1`, `2`, `4`. default: `1`.
6. NUM_DISKS: (Test using drives.) type: int32 default: `1`.
Here's an example of using ```--set``` to modify ```NUM_SOCKETS``` value and ```NUM_DISKS``` value.
```shell
./ctest.sh -R test_static_db_bench_rocksdbiaa_zstd_readrandom_pkm -VV --set NUM_DISKS=2 --set NUM_SOCKETS=2
```

### KPI
Run the [`list-kpi.sh`](/script/benchmark/list-kpi.sh) script to parse the KPIs from the validation logs. 

The expected output will be similar to this. Please note that the numbers might be slightly different. 
Primary KPI is `Total OPS (ops/sec)` which has a * as prefix
#### readrandomwriterandom
```
Total OPS: xxxxx
Avg P50 GET Latency: xxxxx
Avg P99 GET Latency: xxxxx
Avg P50 PUT Latency: xxxxx
Avg P99 PUT Latency: xxxxx
```

#### readrandom
```
Total OPS: xxxxx
Avg P50 GET Latency: xxxxx
Avg P99 GET Latency: xxxxx
```

### Docker Image
The docker image for this workload is:
* `rocksdb-iaa` - Docker image of database with dbbench.

### Notes
1. To avoid runtime issues with illegal instruction sets, compile the docker image on the platform being tested.
2. When using IAA as the compressor/decompressor, the IAA device may be dedicated or the driver of IAA device is too old, or the kernel version problem, so db_bench may not be able to use the IAA device normally, in this case, db_bench will use the soft compressor/decompressor by default. You can grep ```WARNING: com.intel.iaa_compressor_rocksdb compression is not enabled``` in the log directory. If it exists, it means that the IAA device is unavailable, so please meaningfully troubleshoot based on the situation described above


### Index Info
- Name: `RocksDB IAA`
- Category: `DataServices`
- Platform:
- Keywords: `RocksDB`, `IAA`
- Permission:

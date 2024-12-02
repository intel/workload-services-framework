>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

RocksDB is developed and maintained by Facebook Database Engineering Team. The Intel® In-Memory Analytics Accelerator (IAA) plugin for RocksDB provides accelerated compression/decompression in RocksDB using IAA and QPL (Query Processing Library). It has a number of tests that are available to be run.

#### IAA compressor
There are currently testcases that measure Intel IAA compressor performance.
* `test_static_db_bench_rocksdbiaa_readrandom_pkm` - PKM Testcase
   1. This testcase is the PKM Testcase.
   2. This testcase is random read with IAA compressor testcase
* `test_static_db_bench_rocksdbiaa_randomreadrandomwrite_pkm` - PKM Testcase
   1. This testcase is the PKM Testcase.
   2. This testcase is random read and write with IAA compressor testcase
* `test_static_db_bench_rocksdbiaa_readrandom_gated` - Gated Testcase
   1. This testcase is the Gated Testcase.


### Zstd compressor
There are currently testcases that measure Zstd compressor performance.
* `test_static_db_bench_rocksdbiaa_zstd_readrandom_pkm`
   1. This testcase is random read with Zstd compressor testcase

### Docker Image

#### Docker Image with workload benchmarking scripts
The RocksDB stack contains 1 docker images: `Dockerfile.2.rocksdb.iaa`

#### Docker Image for common RocksDB Software stack only.
There is one docker images for unit test with simple RocksDB command: `Dockerfile.1.rocksdb.iaa.unittest`, which benchmarking scripts for RocksDB.

### Config IAA Device on host
The BIOS must be configured with VT-d and PCI ENQCMD enabled, as follows:
```
EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
```
The VT-d must be enabled from the kernel command line.
```
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
sudo reboot
```

### Contact

>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

Apache Spark is a unified analytics engine for large-scale data processing.
This workload implements TPC-DS benchmark for testing Spark cluster performance.
Benchmark is using [spark-sql-perf](https://github.com/databricks/spark-sql-perf) kit for data generation and query execution.

HDFS (Hadoop File System) is used for storing data in Parquet file format.


### Test Case

Workload implements TPC-DS decision support benchmarks.

**TPC-DS** via [tpc.org](http://www.tpc.org/tpcds)
> TPC-DS is a decision support benchmark that models several generally applicable aspects of a decision support system, including queries and data maintenance. The benchmark provides a representative evaluation of performance as a general purpose decision support system. A benchmark result measures query response time in single user mode, query throughput in multi user mode and data maintenance performance for a given hardware, operating system, and data processing system configuration under a controlled, complex, multi-user decision support workload.

- **SCALE_FACTOR**: `gated`, `pkm`, `1000`

The test case with suffix `_gated` is run using `1` scale factor.
The test case with suffix `_pkm` is run using `100` scale factor.

Scale factor determines size of the database that the queries will be run against.
Database size varies from 1GB to 1TB.

Test cases:
```
  Test #1: test_aws_tpcds-spark_gated
  Test #2: test_aws_tpcds-spark_1
  Test #3: test_aws_tpcds-spark_pkm
  Test #4: test_aws_tpcds-spark_250
  Test #5: test_aws_tpcds-spark_500
  Test #6: test_aws_tpcds-spark_1000

Total Tests: 6

```

### Docker Image


### KPI

There are 99 TPC-DS queries, some of which come in two variants (a and b), which gives 103 queries in total.

The primary KPI of workload is defined as test execution time (`*Test execution time` field) and represents a summary time of executing queries.
Other KPIs are query execution times for all queries.


```


### Customize Test Configurations

Parameters for workload configuration:

Spark settings:
* `SPARK_EXECUTOR_CORES` - Number of cores assigned to each executor. It is recommended to keep it between 4 and 6
* `SPARK_MEMORY_FRACTION` - Fraction of the heap space used for execution and storage (default: 0.6)
* `SPARK_MEMORY_STORAGE_FRACTION` - The size of the storage region within the space set aside by spark.memory.fraction (default: 0.5)
* `SPARK_PARALLELISM_FACTOR` - Number of partitions per core (default: 2)
* `SPARK_EXECUTOR_MEMORY_OVERHEAD` - Additional memory to the Spark Executor process(default: 1)

### Performance BKM

If `MOUNT_DISK` is set to true each node required disk mount under /mnt/disk1 to work.
Number of workers is determined by `NUM_WORKERS` value in validate.sh and should not be changed.

When running on cloud requirements for instances are:
_gated:
- 16 vCPUs and 64GB
- 100GB OS disk size
_pkm:
- 32 vCPUs and 128GB
- 200GB OS disk size
- 200GB disk mount
_1000:
- 64 vCPUS and 256GB
- 500GB OS disk size
- 1000GB disk mount

Workload Performance BKM:

- 4 nodes with the same CPU and memory. For each node: 2 sockets per platform, 1 DIMM per memory channel with max supported speed, 1T Memory capability,  6TB hard disk.
- Network Environment: Connect client and worker platforms to same switch, Speed: > 25000Mb/s, Port: Direct Attach Copper.
- BIOS setting:
    - Hyper-Threading: Enable
      - BIOS setting address: Advanced -> Processor Configuration -> Intel(R) Hyper-Threading Tech: Enabled
    - Turbo: Enable
      - BIOS setting address: Advanced -> Power & Performance -> CPU P State Control -> Intel(R) Turbo Boost Technology: Enabled
    - Boot Performance Mode: Max Performance
      - BIOS setting address: Advanced -> Power & Performance -> CPU Power and Performance Policy: Performance
    - Energy Efficient Turbo: Disable
      - BIOS setting address: Advanced -> Power & Performance -> CPU P State Control -> Energy Efficient Turbo: Disabled
    - MLC Streamer Prefetching: Enabled
      - BIOS setting address: Advanced -> Processor Configuration -> MLC Streamer: Enabled
    - MLC Spatial Prefetching: Enabled
      - BIOS setting address: Advanced -> Processor Configuration -> MLC Spatial Prefetcher: Enabled
    - DCU Streamer Prefetching: Enabled
      - BIOS setting address: Advanced -> Processor Configuration -> DCU Data Perfetcher: Enabled
    - DCU IP Prefetching: Enabled
      - BIOS setting address: Advanced -> Processor Configuration -> DCU Instruction Prefetcher: Enabled
- OS setting:
    - cpupower frequency-set -g performance
    - set the max number of open files to be 1048576

      Add following lines into /etc/security/limits.conf

          ```
          * soft nofile 1048576
          * hard nofile 1048576
          ```
    - Disable SWAP and THP:

          ```
          sysctl -w vm.swappiness=0
          echo never > /sys/kernel/mm/transparent_hugepage/defrag
          echo never > /sys/kernel/mm/transparent_hugepage/enabled
          ```





- Known Issues:
  - None

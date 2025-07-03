>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The Yahoo! Cloud Serving Benchmark (YCSB) is an open-source specification and program suite for evaluating retrieval and maintenance capabilities of computer programs. It is often used to compare relative performance of NoSQL database management systems.

MongoDB is a source-available cross-platform document-oriented database program. Classified as a NoSQL database program, MongoDB uses JSON-like documents with optional schemas.

This workload uses ycsb to measure MongoDB performance.

Note: Starting in MongoDB 6.1, journaling is always required. As a result, MongoDB removes the `storage.journal.enabled` option and the corresponding `--journal` and `--nojournal` command-line options. For benchmarking those versions using this workload you don't have to specify anything. The `JOURNAL_ENABLED` tunable is available only for `441` and `604` images. For all other versions journal is enabled by default by the executable and those options are removed from `mongod.conf`. This means that with the disk will be heavily used in test cases except `*_read` test case. Therefore, you must ensure to use the fastest available disk, especially when running cloud instance benchmarking so that the workload run is not disk bound.


### Quick Start
Steps:  
  - Step 1: Clone code from https://github.com/intel/workload-services-framework.git
  - Step 2: Switch to code root path and run command "mkdir build".
  - Step 3: Go to path *"../script/terraform"* and edit file *terraform-congig.static|aws|gcp|...|.tf* to set your node information.
  - Step 4: Go to path *"../build"* and Run below command to configure the ctest.  
            *"cmake  -DPLATFORM=<PLATFORM>  -DBACKEND=terraform   -DCUMULUS_SUT=static -DREGISTRY="your registry IP:port" -DRELEASE=<release version> .."*  
            According to your test bed, *'PLATFORM'* can be changed to ICX/SPR/EMR. *'DCUMULUS_SUT'* can be changed to aws or azure.  
  - Step 5: Go to path *"../build/Workload/Mongo-ycsb"* and and run *"make"* command. If you want to use the released images of WSF, you can specify the **-DRELEASE** like `v23.17.7` and skip to run *"make"*.
  - Step 6: Run below command to run Mongo-ycsb test cases.  
            *./ctest.sh --testcase test_static_ycsb_mongodb441_base_90read10update --set CLIENT_COUNT=0 --set CLIENT_SERVER_PAIR=1 --set THREADS=28 --set NUMACTL_OPTION=0 --options="--svrinfo --sar --collectd --intel_publish --owner=<owner>" --loop=1 --run=1 -V*. Fore more about `--options`, please refer to [terraform-options](../../doc/user-guide/executing-workload/terraform-options.md).    

### Current Support Machine Instance
- Bare metal
`ICX/SPR/EMR/GNR``

- Cloud
`AWS/GCP/Azure/AliCloud/Tencent Cloud``

Also, there is a common test configuration for reference (/test-config/90read10update_common.yaml).

### Known Issue
NA

### Docker Image

Images in this workload can be used almost exactly like the official DockerHub MongoDB image. The naming of MongoDB images follow the rules: <PLATFORM>-mongodb<VERSION>-<USAGE>. PLATFORM can be amd64 and arm64; VERSION can be 441/604/700, ... ; USAGE can be `base` (baseline; with container OS Ubuntu 22.04), `ubuntu2404` (with container OS Ubuntu 24.04) `redhat` (with container OS Redhat ubi8:8.6) and `iaa` (intel optimized with iaa).

- amd64-mongodb710-iaa: Intel Optimzed with IAA MongoDB 7.1.0 on amd64 platform;
- amd64-mongodb441-base: Base MongoDB 4.4.1 on amd64 platform;
- arm64-mongodb441-base: Base MongoDB 4.4.1 on arm64 platform;
- amd64-mongodb604-base: Base MongoDB 6.0.4 on amd64 platform;
- amd64-mongodb604-redhat: MongoDB 6.0.4 on RedHat amd64;
- amd64-mongodb604-ubuntu2404: MongoDB 6.0.4 on Ubuntu 2404 amd64 platform;
- arm64-mongodb604-base: Base MongoDB 6.0.4 on arm64 platform;
- arm64-mongodb604-redhat: MongoDB 6.0.4 on RedHat arm64.
- arm64-mongodb604-ubuntu2404: MongoDB 6.0.4 on Ubuntu 2404 arm64 platform;
- amd64-mongodb700-base: Base MongoDB 7.0.0 on amd64 platform;
- arm64-mongodb700-base: Base MongoDB 7.0.0 on arm64 platform;
- ycsb-0.17.0-base: Base YCSB 0.17.0 image;
- ycsb-0.17.0-optimized: Optimized YCSB 0.17.0 for IAA/QAT.

Please refer to [MongoDB stack](../../stack/MongoDB/README.md).

### Infrastructure

```
                                        Client Instances
                                         ┌───────────┐
                                         │   YCSB    │
                                         │ Container │
                                         │           │
                           ┌─────────────┤    ...    │ ─────┐
                           │             │           │      │
                           │             │   YCSB    │      │  
                           │             │ Container │      │  
                           │             └───────────┘      │  
                           │                  ...           │  
                    ┌──────▼──────┐      ┌───────────┐      │  
                    │   MongoDB   │      │   YCSB    │      │  
                    │  Container  │      │ Container │      │  
                    │             │      │           │      │  
                    │     ...     ◄──────┤    ...    │      │
                    │             │      │           │      │
                    │   MongoDB   │      │   YCSB    │      │  
                    │  Container  │      │ Container │      │  nx Client Node
                    └──────▲──────┘      └───────────┘      │  
 1x Worker Node            │                  ...           │  Number of Client Node 
                           │             ┌───────────┐      │  is based on CLIENT_NODE
 Number of MongoDB         │             │   YCSB    │      │  
 containers is based       │             │ Container │      │  Number of YCSB container
 on CLIENT_SERVER_PAIR     │             │           │      │  is based on CLIENT_SERVER_PAIR
                           │             │    ...    │      │
                           └─────────────┤           │ ─────┘  Each YCSB container stresses a
                                         │   YCSB    │         MongoDB container
                                         │ Container │                   
                                         └───────────┘

```

### Workload

There are serival types of workload in Mongo-ycsb (default: ycsb_mongodb441_base). 

- `ycsb_mongodb441_base`
- `ycsb_mongodb604_base`
- `ycsb_mongodb604_redhat`
- `ycsb_mongodb604_ubuntu2404`
- `ycsb_mongodb700_base`
- `ycsb_mongodb710_iaa`

The naming of workloads follow the rules: `ycsb_mongodb<VERSION>_<USAGE>`:
- `VERSION`: the version of MongoDB, can be set as `441/604/700/710`; 
- `USAGE`: can be set as `base` `ubuntu2404` `redhat` and `iaa` ; `base` means the baseline of MongoDB with container OS Ubuntu 22.04; `ubuntu2404` means MongoDB will be installed on Ubuntu 24.04; `redhat` means MongoDB will be installed on RedHat;`iaa`  means intel optimized MongoDB with iaa.

### Test Case

Below are the list of testcase(s) for MongoDB.

There are currently 6 testcases that measure MongoDB performance:
* `test_<SUT>_<WORKLOAD>_gated`
This testcase is the gated.
* `test_<SUT>_<WORKLOAD>_pkm` 
For Post-Si performance analysis. Default trace collection starts at the 5th minute and lasting for 5 minutes. Other conditions are same as test case mongodb_ycsb_90read10update
* `test_<SUT>_<WORKLOAD>_90read10update`
Read to write ratio is 9:1
* `test_<SUT>_<WORKLOAD>_30write70read` 
The write to read ratio is 3:7
* `test_<SUT>_<WORKLOAD>_write`
Purely write
* `test_<SUT>_<WORKLOAD>_read` 
Purely read
* `test_<SUT>_<WORKLOAD>_iaa` 
Run workload with IAA

### KPI

Run the [`list-kpi.sh`](../../doc/user-guide/collecting-results/list-kpi.md) script to parse the KPIs from the validation logs. 

The expected output should be similar to this. Please note that the numbers might be slightly different. 

```
There are 2 phases in ycsb benchmark test. First is load phase, ycsb insert data into MongoDB. The second is run phase, It may contain operations such as insert update read. ycsb operate data which is inserted into MongoDB in 1st phase.

Counter of [LOAD PHASE]: 0
[OVERALL] Throughput(ops/sec):  838.9261744966443
[CLEANUP], AverageLatency(us):  389.9
[INSERT] AverageLatency(us):  7694.857
[INSERT] MinLatency(us):  741
[INSERT] MaxLatency(us):  685055
[INSERT] 99thPercentileLatency(us):  3171
Counter of [RUN PHASE]: 0
[OVERALL] Throughput(ops/sec):  9721.00709633518
[READ] AverageLatency(us):  966.01960414075
[READ], MinLatency(us): 204
[READ], MaxLatency(us): 108799
[READ], 99thPercentileLatency(us): 1672
[CLEANUP], AverageLatency(us):  603.7
[UPDATE] AverageLatency(us):  948.4432182985554
[UPDATE], MinLatency(us):  221
[UPDATE], MaxLatency(us):  106367
[UPDATE], 99thPercentileLatency(us):  1598
Summary:
*Mean of [RUN PHASE] P99 insert latency(us): 0
*Mean of [RUN PHASE] P99 read latency(us): 1545
*Mean of [RUN PHASE] P99 update latency(us): 1544.25
Mean of [run phase] Throughput(ops/sec): 10300.5
*Sum of [run phase] Throughput(ops/sec): 41201.8

Below are explaination for the report:
Counter of [LOAD PHASE]: 0
[OVERALL] Throughput(ops/sec) : The average throughput is 1941 operations/sec (across all threads) in Load Phase.
[INSERT] AverageLatency(us) : The average latency of insert operations in load phase, in this case, it is 4048 us.
[INSERT], MinLatency(us) : The minimum latency of insert operation in load phase, in this case, it is 290 us.
[INSERT], MaxLatency(us) : The maximum latency of insert operation in load phase, in this case, it is 68991 us.
[INSERT] 99thPercentileLatency(us): The 99 percent latency of INSERT operation in load phase, in this case, it is 3171 us.
Counter of [RUN PHASE]: 0
[OVERALL] Throughput(ops/sec) : The average throughput is 192305 operations/sec (across all threads) in RUN phase.
[READ] AverageLatency(us) : The average latency of Read operations in run phase, in this case, it is 148 us.
[READ], MinLatency(us) : The minimum latency of Read operation in load phase, in this case, it is 59 us.
[READ], MaxLatency(us) : The maximum latency of READ operation in load phase, in this case, it is 67775 us.
[READ], 99thPercentileLatency(us): The 99 percent latency of READ operation in load phase, in this case, it is 67775 us.
[UPDATE] AverageLatency(us) : The average latency of UPDATE operations in run phase, in this case, it is 190 us.
[UPDATE], MinLatency(us) : The minimum latency of UPDATE operation in load phase, in this case, it is 74 us.
[UPDATE], MaxLatency(us) : The maximum latency of UPDATE operation in load phase, in this case, it is 18911 us.
[UPDATE], 99thPercentileLatency(us): The 99 percent latency of UPDATE operation in load phase, in this case, it is 1598 us.
*Mean of [RUN PHASE] P99 insert latency(us): The average of 99% of the latency of all instances of insert in the run phase
*Mean of [RUN PHASE] P99 read latency(us): The average of 99% of the latency of all instances of read in the run phase
*Mean of [RUN PHASE] P99 update latency(us): The average of 99% of the latency of all instances of update in the run phase
Mean of [run phase] Throughput(ops/sec): The average value of each instance of all instances in the run phase
*Sum of [run phase] Throughput(ops/sec): Total throughput of all instances in the run phase
```

### Customize Test Configurations
Refer to [`ctest.md`](../../doc/user-guide/executing-workload/ctest.md#Customize%20Configurations) to customize test parameters.

#### Parameters for workload configure:

##### Workload parameters:

* `EVENT_TRACE_PARAMS`: For collecting trace data.
* `CLIENT_SERVER_PAIR`: The number of `mongod` and `ycsb` instance number. ((value: `<number>`); default: 3)
* `CLIENT_COUNT` - Number of physical machines running ycsb instance. (value: `<number>`)
* `RUN_SINGLE_NODE` - Enable running the workload on the single node, note: `CLIENT_COUNT=0` equal to `RUN_SINGLE_NODE=true`. (value: `true/false`)
* `NUMACTL_OPTION` - Combination of cores and MongoDB instances:
  - `0` - mongodb default bind, `numactl --interleave=all`, recommended by MongoDB
  - `1` - bind all mongodb instances to all numanode evenly
  - `2` - bind all mongodb instances to a numanode
  - `3` - used in combination with `CORE_NUMS_EACH_INSTANCE` to bind each mongodb instance with specific number of cores
  - `4` - used in combination with `CORE_NUMS_EACH_INSTANCE` to bind each mongodb instance with specific number of cores and their paired logical cores
  - `5` - no numa operations.
* `SELECT_NUMA_NODE` - If NUMACTL_OPTION was set to `2/3/4`, this is the selected numa node to run mongod instances; for other NUMACTL_OPTION, this is meaningless. (value: `<number>`; default: 0)
* `CORE_NUMS_EACH_INSTANCE` - The number of cores you want to bind for each MongoDB instance. (value: `<number>`)
* `CORES` - a set of cores to bind MongoDB instances with specific cpu cores when set `NUMACTL_OPTION=2`. (value: `<number>`, for example, `0-9`)
* `YCSB_CORES` - a set of cores to bind ycsb instances with specific cpu cores  when set `NUMACTL_OPTION=2` or run workload on single node. (value: `<number>`, for example, `10-19`)
* `DB_HOSTPATH` - Map the MongoDB dbpath to the host directory, default is empty, which means no mapping. If you want to map the data of instances tp multi disks, you can set it like "/mnt/disk1%20/mnt/disk2" which means that data of MongoDB instances will be map to disk1 and disk2 evenly. (value: for example: `/mnt/disk1`, `/mnt/disk1%20/mnt/disk2`)

* `TLS_FLAG` - Security TLS flag. (value: `true/false`)
* `HERO_FEATURE_IAA` - Enable hero feature of IAA, need to make sure the environment support IAA. (value: `true/false`)
* `CUSTOMER_NUMAOPT_CLIENT` - Customer numactl parameters for YCSB.
* `CUSTOMER_NUMAOPT_SERVER` - Customer numactl parameters for MongoDB.
* `JOURNAL_ENABLED` - Enable or disable the durability journal to ensure data files remain valid and recoverable. (value: `true/false`)
* `CACHE_SIZE_GB` - Defines the maximum size of the internal cache that WiredTiger will use for all data. (value: `<number>`)
* `CORE_FREQUENCY_ENABLE` - Enable/disable core frequency scaling. (value: `true/false`; default: false)
* `CORE_FREQUENCY` - Core frequency (Hz). (value: `<number>`)
* `UNCORE_FREQUENCY_ENABLE` - Enable/disable uncore frequency scaling. (value: `true/false`; default: false)
* `UNCORE_FREQUENCY` - Uncore frequency (Hz). (value: `<number>`)

##### YCSB parameters:

* `WORKLOAD_FILE` - Workload file for ycsb. (value: `NA/90Read10Update/workloada_combined/workload_query`)
* `THREADS` - Number of YCSB client threads. (value: `<number>`)
* `OPERATION_COUNT` - The number of operations to perform in the workload. (value: `<number>`)
* `RECORD_COUNT` - The number of records in the dataset at the start of the workload. used when loading for all workloads. (value: `<number>`)
* `INSERT_START` - Offset of the first inserted value. (value: `<number>`)
* `INSERT_COUNT` - Refers to the number of records that were inserted into the database. (value: `<number>`)
* `INSERT_ORDER` - Specifies the order in which new records are inserted into the database. (value: `SEQUENTIAL/RANDOM` )
* `READ_PROPORTION` - Indicates the ratio of read operations to all operations.  (value: `<number>`)
* `UPDATE_PROPORTION` - Indicates the ratio of update operations to all operations. (value: `<number>`)
* `INSERT_PROPORTION` - Indicates the ratio of scan operations to all operations. (value: `<number>`)
* `SCAN_PROPORTION` - Indicates the ratio of scan operations to all operations. (value: `<number>`)
* `FIELD_COUNT` - The number of fields in the record. (value: `<number>`)
* `FIELD_LENGTH` - Field size. (value: `<number>`)
* `MIN_FIELD_LENGTH` - Minimun field size. (value: `<number>`)
* `READ_ALL_FIELDS` - Should read all fields (true), only one (false). (value: `true/false`)
* `WRITE_ALL_FIELDS` - Should write all fields (true), only one (false). (value: `true/false`)
* `READ_MODIFY_WRITE_PROPORTION` - Refers to the proportion of operations that read a record, modify it, and write it back. (value: `<number>`)
* `REQUEST_DISTRIBUTION` - What distribution should be used to select records to operate on: uniform, zipfian, hotspot, sequential, exponential and latest.
* `MIN_SCANLENGTH` - Minimum number of records to scan. (value: `<number>`)
* `MAX_SCANLENGTH` - Maximum number of records to scan. (value: `<number>`)
* `SCAN_LENGTH_DISTRIBUTION` - What distribution should be used for scans to choose the number of records to scan, between 1 and maxscanlength for each scan. (value: `UNIFORM/ZIPFIAN`)
* `ZERO_PADDING` - Specifies whether leading zeros should be added to record keys to ensure they have a consistent length. (value: `<number>`)
* `FIELD_NAME_PREFIX` - Specifies a prefix to be added to the field names of records
* `MAX_EXECUTION_TIME` - Ycsb maximum execution time. Unit is seconds. The benchmark runs until either the operation count has exhausted or the maximum specified time has elapsed, whichever is earlier. (value: `<number>`)
* `TARGET` - The target number of operations per second. By default, the YCSB Client will try to do as many operations as it can. For example, if each operation takes 100 milliseconds on average, the Client will do about 10 operations per second per worker thread. However, you can throttle the target number of operations per second. For example, to generate a latency versus throughput curve, you can try different target throughputs, and measure the resulting latency for each. (value: `<number>`)
* `JVM_ARGS` - Specifies the command-line arguments to be passed to the JVM. (default: `-XX:+UseNUMA`)
* `YCSB_MEASUREMENT_TYPE` - Indicates how to present latency measurement timeseries. (value: `TIMESERIES/HISTOGRAM/RAW`)

##### Configurations for IAA devices
* `HERO_FEATURE_IAA` - enable/disbale hero feature of IAA, need to make sure the environment support IAA
* `IAA_MODE` - 0 - shared, 1 - dedicated
```
* `IAA_DEVICES` - 0 - all devices or start and end device number. 
For example, 1, 7 will configure all the Socket0 devices in host or 0, 3  will configure all the Socket0 devices in guest
             9, 15  will configure all the Socket1 devices and son on
             1  will conigure only device 1
IAA_WQ_SIZE: 1-128
```

##### Kubernetes parameters:
resource requests (cpu and memory) of kubernetes: 
  - `KUBERNETES_RESOURCE_REQUESTS` - (value: `true/false`; default: true)
  - `KUBERNETES_RESOURCE_REQUESTS_CPU`
  - `KUBERNETES_RESOURCE_REQUESTS_MEMORY`
resource limits (cpu and memory) of kubernetes:
  - `KUBERNETES_RESOURCE_LIMITS` - (value: `true/false`; default: false)
  - `KUBERNETES_RESOURCE_LIMITS_CPU`
  - `KUBERNETES_RESOURCE_LIMITS_MEMORY`

Notes: Running MongoDB on a system with Non-Uniform Memory Access (NUMA) can cause a number of operational problems, including slow performance for periods of time and high system process usage. Refer to [MongoDB and NUMA Hardware](https://www.mongodb.com/docs/v4.4/administration/production-notes/#mongodb-and-numa-hardware)

### Performance BKM
- HW config
  - ICX: 
    - CPU: Intel(R) Xeon(R) Gold 6338N CPU @ 2.20GHz
    - Core Number: 32 Cores Per Socket
    - Memory: 16 * 32GB @ 2666MT/s DDR4
  - SPR:
    - CPU: Intel(R) Xeon(R) Platinum 8480+
    - Core Number: 56
    - Memory: 32 * 32GB @ 4400MT/s
  - Cloud:
    - ICX: AWS m6i.32xlarge
    - ICX: AWS m6i.16xlarge
- SW config
  - ICX:
    - BIOS/Kernel/OS: SE5C620.86B.01.01.0003.2104260124 / 4.19.91-23.4.an8.x86_64 / Anolis OS 8.4
    - Kernel Setting (Have-to-set-by-manual):
      - `cpupower frequency-set --governor performance`
      - `echo "0" | sudo tee /proc/sys/vm/zone_reclaim_mode`
      - `echo "1" | sudo tee /proc/sys/kernel/numa_balancing`
    - Workload Parameters
      - CLIENT_SERVER_PAIR=16
      - THREADS=64
      - NUMACTL_OPTION=1
      - CLIENT_COUNT=3
      - RECORD_COUNT=4000000

  - SPR:
    - BIOS/Kernel/OS: EGSDCRB1.86B.0078.D27.2204181335 / 5.15.0-spr.bkc.pc.2.10.0.x86_64 / CentOS Stream 8
    - Kernel Setting (Have-to-set-by-manual):
      - `cpupower frequency-set --governor performance`
      - `echo "0" | sudo tee /proc/sys/vm/zone_reclaim_mode`
      - `echo "1" | sudo tee /proc/sys/kernel/numa_balancing`
    - Workload Parameters:
      - CLIENT_SERVER_PAIR=16
      - THREADS=64
      - NUMACTL_OPTION=2
      - CLIENT_COUNT=3
      - RECORD_COUNT=4000000

  - m6i.32xlarge:
    - Kernel Setting (Have-to-set-by-manual):
    - Workload Parameters:
      - CLIENT_SERVER_PAIR=16
      - THREADS=64
      - NUMACTL_OPTION=1
      - CLIENT_COUNT=3
      - RECORD_COUNT=4000000
  
  - m6i.16xlarge:
    - Kernel Setting (Have-to-set-by-manual):
    - Workload Parameters:
      - CLIENT_SERVER_PAIR=8
      - THREADS=64
      - NUMACTL_OPTION=2
      - CLIENT_COUNT=3
      - RECORD_COUNT=4000000

- BIOS setting
  - ICX:
    - Intel(R) Hyper-Threading Tech: Enable
    - CPU Power and Performance Policy: Performance
    - Intel(R) Turbo Boost Technology: Enable
    - Energy Efficient Turbo: Enable
    - Workload Configuration: I/O Sensitive
    - Package C State: C0/C1 state
    - C1E: Enable
    - Enhanced Intel SpeedStep(R) Tech: Enable
    - Hardware P-States: Disable
    - Processor C6: Disable
    - MLC Streamer: Enable
    - MLC Spatial Prefetcher: Enable
    - DCU Data Prefetcher: Enable
    - DCU Instruction Prefetcher: Enable
    - LLC Prefetch: Enable
  - SPR:
    - Enable LP [Global]: All LPs
    - SNC: Disable
    - Boot performance mode: Max Performance
    - Energy Efficient Turbo: Enable
    - Turbo Mode: Enable
    - Workload Configuration: I/O Sensitive
    - Package C State: C0/C1 state
    - C1E: Enable
    - Enhanced Intel SpeedStep(R) Tech: Enable    
    - Hardware P-States: Disable
    - CPU C6 report: Disable
    - Hardware Prefetcher: Enable
    - Adjacent Cache Prefetch: Enable
    - DCU Streamer Prefetcher: Enable
    - DCU IP Prefetcher: Enable
    - LLC Prefetch: Enable

- RUN CMD
  - ICX:
    - ```export CLIENT_SERVER_PAIR=16;export CLIENT_COUNT=3;export NUMACTL_OPTION=1;export THREADS=64;./ctest.sh -R test_mongodb_ycsb_90read10update -VV```
  - SPR:
    - ```export CLIENT_SERVER_PAIR=16;export CLIENT_COUNT=3;export NUMACTL_OPTION=2;export THREADS=64;./ctest.sh -R test_mongodb_ycsb_90read10update -VV```
  - m6i.32xlarge:
    - ```export CLIENT_SERVER_PAIR=16;export NETWORK_RPS_TUNE_ENABLE=true;export CLIENT_COUNT=3;export NUMACTL_OPTION=1;export THREADS=64;./ctest.sh -R test_mongodb_ycsb_90read10update -VV```
  - m6i.16xlarge:
    - ```export CLIENT_SERVER_PAIR=8;export CLIENT_COUNT=3;export NUMACTL_OPTION=2;export THREADS=64;./ctest.sh -R test_mongodb_ycsb_90read10update -VV```


### Resource Requirement
- Cloud;
- Baremetal: cluster nodes should be in the same switch network.

### Index Info
- Name: `Mongo ycsb`  
- Category: `DataServices`  
- Platform: `SPR`, `ICX`, `EMR`, `SRF`, `GNR`
- Keywords: `No-SQL`, `DocumentDB`, `Database`  
- Permission:      
- Supported Labels: `HAS-SETUP-HUGEPAGE-2048kB-4096`, `HAS-SETUP-DISK-MOUNT-1`   


### See Also

- [MongoDB stack](../../stack/MongoDB/README.md)

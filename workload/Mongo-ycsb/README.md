>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
---
Please note that MongoDB depend on software subject to non-open sourcelicenses. If you use or redistribute this software, it is your sole responsibility to ensure compliance with such licenses https://www.mongodb.com/licensing/server-side-public-license.
---

### Introduction

The Yahoo! Cloud Serving Benchmark (YCSB) is an open-source specification and program suite for evaluating retrieval and maintenance capabilities of computer programs. It is often used to compare relative performance of NoSQL database management systems.

MongoDB is a source-available cross-platform document-oriented database program. Classified as a NoSQL database program, MongoDB uses JSON-like documents with optional schemas.

This workload uses ycsb to measure MongoDB performance.

Note: Starting in MongoDB 6.1, journaling is always required. As a result, MongoDB removes the `storage.journal.enabled` option and the corresponding `--journal` and `--nojournal` command-line options. For benchmarking those versions using this workload you don't have to specify anything. The `JOURNAL_ENABLED` tunable is available only for `441` and `604` images. For all other versions journal is enabled by default by the executable and those options are removed from `mongod.conf`. This means that with the disk will be heavily used in test cases except `*_read` test case. Therefore, you must ensure to use the fastest available disk, especially when running cloud instance benchmarking so that the workload run is not disk bound.

### Quick Start
Steps:  
  - Step 1: Clone code
  - Step 2: Switch to code root path and run command "mkdir build".
  - Step 3: Go to path *"../script/terraform"* and edit file *terraform-congig.static|aws|gcp|...|.tf* to set your node information.
  - Step 4: Go to path *"../build"* and Run below command to configure the ctest.  
            *"cmake  -DPLATFORM=<PLATFORM>  -DBACKEND=terraform   -DCUMULUS_SUT=static -DREGISTRY="your registry IP:port" -DRELEASE=<release tag> .."*  
            According to your test bed, *'PLATFORM'* can be changed to ICX/SPR. *'DCUMULUS_SUT'* can be changed to aws or azure.  
  - Step 5: Go to path *"../build/Workload/Mongo-ycsb"* and and run *"make"* command. If you want to use the released images of WSF, you can specify the **-DRELEASE** `<release tag>` and skip to run *"make"*.
  - Step 6: Run below command to run Mongo-ycsb test cases.  
            *./ctest.sh --testcase test_static_ycsb_mongodb604_base_90read10update --set CLIENT_COUNT=0 --set CLIENT_SERVER_PAIR=1 --set THREADS=28 --set NUMACTL_OPTION=0 --options="--svrinfo --sar --collectd --intel_publish --owner=<owner>" --loop=1 --run=1 -V*. Fore more about `--options`, please refer to [terraform-options](../../doc/user-guide/executing-workload/terraform-options.md).    

### Current Support Machine Instance
- Bare mental
`ICX/SPR/`

- Cloud
`AWS/GCP/Azure/AliCloud/Tencent Cloud`

### Known Issue
NA

### Docker Image

Images in this workload can be used almost exactly like the official DockerHub MongoDB image.

- amd64-mongodb604-base: Base MongoDB 6.0.4 on amd64 platform;
- ycsb-0.17.0-base: Base YCSB 0.17.0 image;

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

### KPI

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
Refer to [`ctest.md`](../../doc/user-guide/executing-workload/ctest.md) to customize test parameters.

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
* `CUSTOMER_NUMAOPT_CLIENT` - Customer numactl parameters for YCSB.
* `CUSTOMER_NUMAOPT_SERVER` - Customer numactl parameters for MongoDB.
* `JOURNAL_ENABLED` - Enable or disable the durability journal to ensure data files remain valid and recoverable. (value: `true/false`)
* `CACHE_SIZE_GB` - Defines the maximum size of the internal cache that WiredTiger will use for all data. (value: `<number>`)


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

##### Kubernetes parameters:
resource requests (cpu and memory) of kubernetes: 
  - `KUBERNETES_RESOURCE_REQUESTS` - (value: `true/false`; default: true)
  - `KUBERNETES_RESOURCE_REQUESTS_CPU`
  - `KUBERNETES_RESOURCE_REQUESTS_MEMORY`
resource limits (cpu and memory) of kubernetes:
  - `KUBERNETES_RESOURCE_LIMITS` - (value: `true/false`; default: false)
  - `KUBERNETES_RESOURCE_LIMITS_CPU`
  - `KUBERNETES_RESOURCE_LIMITS_MEMORY`

Notes: Running MongoDB on a system with Non-Uniform Memory Access (NUMA) can cause a number of operational problems, including slow performance for periods of time and high system process usage. Refer to [MongoDB and NUMA Hardware](https://www.mongodb.com/docs/v6.0/administration/production-notes/#mongodb-and-numa-hardware)

### Performance BKM

Please refer to [MongoDB* Tuning Guide on 3rd Generation Intel® Xeon® Scalable Processors](https://www.intel.com/content/www/us/en/developer/articles/guide/mongodb-tuning-guide-on-xeon-based-systems.html)
Thee main workload's parameters recommended are:
```
THREADS=64
CLIENT_SERVER_PAIR=<X> ## Depending on the vCPUs available in the particular instance, typically 1 for <32 vCPUs, 4 for >=32 vCPUs & < 64 vCPUs, 8 for >=64 vCPUs.
RECORD_COUNT=20000000
```

There is a [common test configuration](test-config/90read10update_common.yaml) for reference.

### Index Info
- Name: `Mongo ycsb`  
- Category: `DataServices`  
- Platform: `SPR`, `ICX`
- Keywords: `MongoDB 6.0.4`, `YCSB`, `Multi Node`, `Single Node`  
- Permission:   

### See Also
- [MongoDB Documentation](https://www.mongodb.com/docs/v6.0/)
- [Yahoo! Cloud Serving Benchmark (YCSB)](https://github.com/brianfrankcooper/YCSB/wiki#yahoo-cloud-serving-benchmark-ycsb)
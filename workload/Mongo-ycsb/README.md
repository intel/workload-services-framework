>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The Yahoo! Cloud Serving Benchmark (YCSB) is an open-source specification and program suite for evaluating retrieval and maintenance capabilities of computer programs. It is often used to compare relative performance of NoSQL database management systems.

MongoDB is a source-available cross-platform document-oriented database program. Classified as a NoSQL database program, MongoDB uses JSON-like documents with optional schemas.

This workload uses ycsb to measure Mongodb performance.

### Docker Image

The workload contains 3 docker image
* `ycsb` - ycsb benchmark. As a client.
* `mongodb` - Mongodb server. As a server.
* `redis-server` - redis. For consistency coordination and synchronization.

```
# Deploy workload
m4 -I../../template -I./template -DTESTCASE="<REPLACE_YOUR_TESTCASE_HERE>" kubernetes-config.yaml.m4 > kubernetes-config.yaml
kubectl apply -f kubernetes-config.yaml

# Retrieve logs
mkdir -p logs-<REPLACE_YOUR_TESTCASE_HERE>
pod=$(kubectl get pod --selector=job-name=benchmark -o=jsonpath="{.items[0].metadata.name}")
kubectl exec $pod -- cat /export-logs | tar xf - -C logs-<REPLACE_YOUR_TESTCASE_HERE>

# Delete workload deployment
kubectl delete -f kubernetes-config.yaml
```

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

Below are the list of testcase(s) for Mongodb.

There are currently 6 testcases that measure Mongodb performance:
* `mongodb_ycsb_gated`
This testcase is the gated.
* `mongodb_ycsb_pkm` 
For Post-Si performance analysis. Default trace collection starts at the 5th minute and lasting for 5 minutes. Other conditions are same as test case mongodb_ycsb_90read10update
* `mongodb_ycsb_90read10update`
Read to write ratio is 9:1
* `mongodb_ycsb_30write70read` 
The write to read ratio is 3:7
* `mongodb_ycsb_write`
Purely write
* `mongodb_ycsb_read` 
Purely read

How to run testcase
```
cd build
cmake ..
cd workload/Mongo-ycsb
./ctest.sh -V 
```

### KPI

Run the [`list-kpi.sh`](../../doc/ctest.md#list-kpish) script to parse the KPIs from the validation logs. 

The expected output should be similar to this. Please note that the numbers might be slightly different. 

```
There are 2 phases in ycsb benchmark test. First is load phase, ycsb insert data into mongodb. The second is run phase, It may contain operations such as insert update read. ycsb operate data which is inserted into mongodb in 1st phase.

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
Refer to [`ctest.md`](../../../../../doc/ctest.md#Customize%20Configurations) to customize test parameters.

Parameters for workload configure:
* `EVENT_TRACE_PARAMS`: For collecting trace data.
* `NUMACTL_OPTION` - Combination of cores and MongoDB instances:
  - `0` - mongodb default bind, `numactl --interleave=all`
  - `1` - bind all mongodb instances to all numanode evenly
  - `2` - bind all mongodb instances to a numanode
* `CORES` - a set of cores to bind mongodb instances with specific cpu cores when set `NUMACTL_OPTION=2`. (default: "")
* `YCSB_CORES` - a set of cores to bind ycsb instances with specific cpu cores  when set `NUMACTL_OPTION=2` or run workload on single node. (default: "")
* `CLIENT_COUNT` - Number of physical machines running ycsb instance. (default: 1)
* `RUN_SINGLE_NODE` - Enable running the workload on the single node. (default: flase)
* `THREADS` - Number of YCSB client threads. (default: 10). 
* `OPERATION_COUNT` - The number of operations to perform in the workload (default: 4000000). 
* `RECORD_COUNT` - The number of records in the dataset at the start of the workload. used when loading for all workloads. (default: 4000000). 
* `MAX_EXECUTION_TIME` - Ycsb maximum execution time. Unit is seconds (default: 180). The benchmark runs until either the operation count has exhausted or the maximum specified time has elapsed, whichever is earlier.
* `TARGET` - The target number of operations per second. By default, the YCSB Client will try to do as many operations as it can. For example, if each operation takes 100 milliseconds on average, the Client will do about 10 operations per second per worker thread. However, you can throttle the target number of operations per second. For example, to generate a latency versus throughput curve, you can try different target throughputs, and measure the resulting latency for each. (default: 0)
* `CACHE_SIZE_GB` - Defines the maximum size of the internal cache that WiredTiger will use for all data. (default: "") 
* `JOURNAL_ENABLED` - Enable or disable the durability journal to ensure data files remain valid and recoverable. (default: false) 
* `DB_HOSTPATH` - Map the MongoDB dbpath to the host directory, default is empty, which means no mapping. (default: '')
* `NETWORK_RPS_TUNE_ENABLE` - RPS tuning flag on cloud, Default value is false. If set ture, RPS used all cores. (default: false)
* `CUSTOMER_NUMAOPT_CLIENT` - Customer numactl parameters for YCSB. (default: "")
* `CUSTOMER_NUMAOPT_SERVER` - Customer numactl parameters for MongoDB. (default: "")

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
    - Workload Parameters
      - CLIENT_SERVER_PAIR=16
      - THREADS=64
      - NUMACTL_OPTION=1
      - CLIENT_COUNT=3
      - RECORD_COUNT=4000000

  - SPR:
    - BIOS/Kernel/OS: EGSDCRB1.86B.0078.D27.2204181335 / 5.15.0-spr.bkc.pc.2.10.0.x86_64 / CentOS Stream 8
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
- Baremental: cluster nodes should be in the same switch network.

### Index Info
- Name: `Mongo ycsb`  
- Category: `DataServices`  
- Platform:  `SPR`, `ICX`  
- Keywords:   
- Permission:   



>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Index

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Test Case](#test-case)
- [Test Parameter](#test-parameters)
- [KPI](#kpi)
- [Index info](#index-info)

### Introduction

This workload uses the `memtier_benchmark` traffic generator by RedisLabs to benchmark memory performance, with the in-memory NoSQL key-value store Redis as the use case.
The workload supports only kubernetes platform, it will schedual redis memtier and redis server on defferent Kubernetes nodes so that we can get accurate performance data. 

The workload contains two stage, the first one is a population where we warm up the Redis by write-only pressures, and it does not count into the final KPI. The second stage is formal execution, where we run the test case as we defined and gets our KPI.

Test can be executed on multinode and singlenode depend on your parameter settings of `RUN_SINGLE_NODE` and `CLIENT_COUNT` (see [Test Parameter](#test-parameters)). 

- MultiNode: Redis server will be scheduled to the worker node while memtier processes spawned on the remaining nodes evenly.

- SingleNode: Redis server and Memtier will be scheduled to the worker node, but on different socket.

### Quick Start

#### Prerequisite

- OS: This workload has been tested on Centos 9, Ubuntu 22.04, Ubuntu 24.04, Debian 10.

- System: Redis is a memory-intensive workload. For any given test case, the executing system should have at least 5.2GB of available memory per Redis instance on worker node. 

- Cluster: Redis-Memtier-Native can be execuated on both multinodes and singlenode depend on your parameters settings.

#### How to run

- Step 1: Download WSF code and navigate to the code root directory.

  ```shell
  cd <wsf_work_dir>
  ```
- Step 2: Create "build" folder with command 

  ```shell
  mkdir build
  ```

- Step 3: Refer to files [setup-terraform.md](../../doc/user-guide/preparing-infrastructure/setup-terraform.md) to Prepare your terraform configurations with your SUT information (only required when running on BM. WSF will automatically setup disk on cloud)
  ```shell
  vi script/terraform/terraform-config.<sut>.tf
  ```
  Since this is a native workload, you can always modify controller vm_count to zero.
  For SingleNode scenario, set client vm_count to zero.
  For MultiNode scenario, set client vm_count equals to `CLIENT_COUNT`.
  Taking MultiNode with `CLIENT_COUNT=1` as an example:
  ```shell
  vi script/terraform/terraform-congig.static.tf

  variable "worker_profile" {
    default = {
      vm_count = 1
      hosts = {
        "worker-0": {
          "user_name": "<worker user name>",
          "public_ip": "<worker public ip>",
          "private_ip": "<worker private ip>",
          "ssh_port": 22,
        }
      }
    }
  }
  
  variable "client_profile" {
    default = {
      vm_count = 1
      hosts = {
        "client-0": {
          "user_name": "<client user name>",
          "public_ip": "<client public ip>",
          "private_ip": "<client private ip>",
          "ssh_port": 22,
        }
      }
    }
  }

  variable "controller_profile" {
    default = {
      vm_count = 0 
      hosts = {
        "controller-0": {
          "user_name": "test",
          "public_ip": "127.0.0.1",
          "private_ip": "127.0.0.1",
          "ssh_port": 22,
        }
      }
    }
  }
  ...
  ```
- Step 4: Go to path *"build"* and Run "cmake".  

  ```shell
  cd build
  cmake -DPLATFORM=SPR -DTERRAFORM_SUT=<sut> -DBENCHMARK=redis_memtier ..
  ```

  For more information on `cmake`, please refer to [cmake.md](../../doc/user-guide/executing-workload/cmake.md) and [terraform-options.md](../../doc/user-guide/executing-workload/terraform-options.md)


- Step 5: Run below command to list all test cases.

  ```shell
  cd workload/Redis-Memtier
  make
  ./ctest.sh -N
  ```

- Step 6: Run test case for a quick start here, we are using default parameters.

  ```shell
  ./ctest.sh -R redis_memtier_20write80read -V
  ```

- Step 7: Generate kpi value after case execution completed. Refer to [KPI](#kpi) to check kpi definitions.

  ```shell
  ./list-kpi.sh --all logs*
  ```

### Test Case

The workload predefines six test cases, if you want to modify parameters to generate your own testcases, see [Test Parameter](#test-parameters) section. Aside gated and pkm test cases, the rest are identical except `MEMTIER_RATIO`.

* `redis_memtier_gated` test case is just a functional test, which takes only few seconds and would not do data population, gated case run in a single node.
* `redis_memtier_pkm` is typical testcase for redis, with data population and default operation ratio 1:10 in 5mins.
* `redis_memtier_write` memtier will only generate write operations
* `redis_memtier_20write80read` will generates 80 percent of write operation and 20 of read.
* `redis_memtier_xwriteyread` will customize write and read rate.
* `redis_memtier_read` will only generate read operations.
* `redis_memtier_single_node` will only run redis and memtier on single node, which means that memtier and redis running on the same node.

### Test Parameters

- Important parameters  
  First of all, the parameter that effect the test and perfermance significantly will be introduced. You may need to modify them during your test. More details will be introduce in subsequent chapter.

  * MEMTIER_KEY_MAXIMUM: this parameter controls stage one, memtier will use “-n allkeys” option to ensure that all keys from 0 to key_maximum will be inserted to Redis. If this set too big and reaches out of memory, setups will crush on cloud. We provide an formula to estimate the memory usage later.
  Memory footprint formula:
  To ensure that Redis has been fully used memory and well warmed up, you can approximately use this to estimate memory usage(in Bytes):  
  1.5 * (MEMTIER_DATA_SIZE + 32) * MEMTIER_KEY_MAXIMUM    

  * CPU_USED: this specify how much core you want to use. Redis is basically a single-thread process, one redis process will takeup a core. Always make sure both cores on your client nodes and on your worker node are sufficient. Bydefault is 1.

  * MEMTIER_PIPELINE: this parameter can increase perf significantly, also latency will increase.

  * MEMTIER_THREADS: affect the pressure memtier create, also can affect latency.

  * MEMTIER_CLIENTS: affect the pressure memtier create, also can affect latency.

  * CLIENT_COUNT: number of Client Node, maximum to 3, sometime it is the client that hit the bottleneck and cannot give redis more pressure, in this time try to increase CLIENT_COUNT. Make sure client vm_count in terraform-congig.<sut>.tf equals this parameter.

  * REDIS_PERSISTENCE_POLICY: defines Redis persist data or not. Only inmemory manipulation will be much faster

  * MEMTIER_DATA_SIZE: this parameters has huge impact to networks, if it is too big the KPI will be constrained by networks rather than CPU

  * MEMTIER_TEST_TIME && MEMTIER_REQUESTS: `MEMTIER_TEST_TIME` is set to 300s by default. If `MEMTIER_REQUESTS` is set above zero, then the test duration will be request-based rather than operation-based, i.e., `MEMTIER_TEST_TIME` will be disabled. 

- Genernal Configure:

  * TIMEOUT: Specify timeout for retrieving logs. If running in cloud or remote machine, since this workload has many   pods logs to get and will cost much time, it may fail in default settings.
  
  * CPU_USED: Number of cores used to run redis server. In this workload, each redis instance will be bind to a specific core. Thus, it also means the number of Redis Instances. (default: 1)

  * RUN_SINGLE_NODE: Client and server on same node. (default: false)

  * CLIENT_COUNT: The number of Client Node to run Memtier,1 <= CLIENT_COUNT <=3. (default: 1)

  * EVENT_TRACE_PARAMS: For collecting emon data.

  * START_NUMA_NODE: selected numa node to bind redis instanes. (default: 0)

  * REDIS_NUMACTL_STRATEGY: Combination of cores and Redis instances: (default: 1)    
    `0` - no core bind operation with redis instances 

    `1` - each instance will be bind with a specific physical core with two logical cores 
    
    `2` - each instance will be bind with a specific core (whether HT is on or off) 

    `3` - for single node, redis server and memtier client will be bounded on differnet numa node

    `4` - bind all redis instances to all numanode evenly
    
  * REDIS_SERVER_NUMACTL_OPTIONS: Customize your own redis-server numa-option
  * MEMTIER_CLIENT_NUMACTL_OPTIONS: Customize your own redis-memtier numa-option
  REDIS_SERVER_NUMACTL_OPTIONS, MEMTIER_CLIENT_NUMACTL_OPTIONS are two parameters take effect in single-node scenarios, i.e. , when START_NUMA_NODE=1, these two are the most significant parameters and will overwrite all other numa-related parameters. You can set it as using `numactl` directly, e.g.REDIS_SERVER_NUMACTL_OPTIONS="-N 1 -M 1"; MEMTIER_CLIENT_NUMACTL_OPTIONS="-N 0 -M 0"
  

- Redis server parameters:

  * REDIS_SERVER_IO_THREADS: Number of redis server IO threads to use (default: 0)
  
  * REDIS_SERVER_IO_THREADS_DO_READS: If true, it makes both reads and writes use 
                                    IO threads instead of just writes. (default: false)

  * REDIS_PERSISTENCE_POLICY: Two persistence mechanisms of Redis: \
                            `RDB` (also known as snapshot mode), and the \
                            `AOF` log (also known as append mode). \
                            `false` means Redis does not perform persistent operations. \
                            `default` means nothing to with the redis.conf. (default: default)

  * REDIS_APPENDFSYNC_MODE: The precondition is that REDIS_PERSISTENCE_POLICY set as AOF. \
                          `always` The AOF file will be written every time a data modification occurs. \
                          `everysec` Sync every second, this policy is the default policy of AOF. \ 
                          `no` Never sync.

  * REDIS_RDB_SECONDS: The precondition is that REDIS_PERSISTENCE_POLICY set as RDB. \
                     Frequency of Redis server dump snapshots

  * REDIS_SERVER_IO_THREADS_CPU_AFFINITY: Set redis server/io threads to cpu affinity (default: false)

  * REDIS_EVICTION_POLICY: When the memory usage limit maxmemory is reached, the policy to be used \
                         to clear the cache can be specified by setting REDIS_EVICTION_POLICY. (default: false)

  For any other parameters for redis server, you can also modify [redis_conf.conf](redis_conf.conf).

- Redis memtier benchmark parameters:

  * MEMTIER_REQUESTS: Number of total requests per client (default: 10000)

  * MEMTIER_TEST_TIME: Number of seconds to run the test (SECS, default: 0) 

  * MEMTIER_DATA_SIZE: Object data size in Bytes (default: 4096) , this parameters has huge impact to networks, set it to smaller number (e.g. 128) to reach network bottleneck slower.

  * MEMTIER_PIPELINE: Number of concurrent pipelined requests (default: 1)

  * MEMTIER_CLIENTS: Number of clients per thread (default: 8)

  * MEMTIER_THREADS: Number of threads (default: 2)

  * MEMTIER_RATIO: Set:Get ratio (default: 1:10)

  * MEMTIER_KEY_MINUMUM: Key ID minimum value (default: 0)
  
  * MEMTIER_KEY_MAXIMUM: Key ID maximum value (default: 10000000)
  
  * MEMTIER_KEY_PATTERN: Set:Get pattern in Formal execution phase (default: R:R)
  
  * MEMTIER_LOAD_KEY_PATTERN: Set:Get pattern in populate phase (default: P:P)
  
  * MEMTIER_RANDOMIZE: Indicate that data should be randomized (default: "", set to "true" to enable)
  MEMTIER_DISTINCT_CLIENT_SEED: Use a different random seed for each client (default: "", set to "true" to enable)
  
  * MEMTIER_RUN_COUNT: Number of full-test iterations to perform (default: 1)

- Test config 

  We have two pre-defined test config to help you start quicker. 

  * static_multi_node.yaml: for multinode scenario, running only one redis instance
    ```yaml
      CPU_USED: 1
      MEMTIER_PIPELINE: 6
      MEMTIER_THREADS: 5
      MEMTIER_CLIENTS: 5
      CLIENT_COUNT: 1
      MEMTIER_TEST_TIME: 300
      MEMTIER_DATA_SIZE: 100
      MEMTIER_KEY_MAXIMUM: 10000000
      REDIS_PERSISTENCE_POLICY: false
      MEMTIER_RATIO: "1:4"
    ```
  
  * static_single_node.yaml: for singlenode scenario, running only one redis instance
    ```yaml
      CPU_USED: 1
      MEMTIER_PIPELINE: 6
      MEMTIER_THREADS: 5
      MEMTIER_CLIENTS: 5
      MEMTIER_TEST_TIME: 300
      MEMTIER_DATA_SIZE: 100
      MEMTIER_KEY_MAXIMUM: 10000000
      REDIS_PERSISTENCE_POLICY: false
      MEMTIER_RATIO: "1:4"
      RUN_SINGLE_NODE: true
      REDIS_NUMACTL_STRATEGY: 3
    ```
  
  Change the command in Step 6 as below to use test-config
  ```shell
    ./ctest.sh -R <test-case> --config <config_path> -V
  ```
### KPI

The workload creates the following log files in its output directory:

* `run.log`: General info, including configuration and error output.
* `redis-N.log`: Redis server logs. One per instance.
* `memtier-populateN.log`: Memtier logs for the populate phase. One per instance.
* `memtier-benchN.log`: Memtier logs for the formal execution phase. One per instance.

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs.

A sample output looks like

```
#######################
Formal execution: Instance 0 ops(ops/sec): 191202.45
Formal execution: Instance 0 hit(hits/sec): 152961.83
Formal execution: Instance 0 missed(misses/sec): 0.00
Formal execution: Instance 0 latency average (ms): 0.78195
Formal execution: Instance 0 p99 Latency (ms): 1.22
Formal execution: Instance 0 throughput (KB/s): 26867.08
Formal execution: Instance 2 ops(ops/sec): 195448.13
Formal execution: Instance 2 hit(hits/sec): 156358.39
Formal execution: Instance 2 missed(misses/sec): 0.00
Formal execution: Instance 2 latency average (ms): 0.76481
Formal execution: Instance 2 p99 Latency (ms): 1.18
Formal execution: Instance 2 throughput (KB/s): 27463.67
Formal execution: Instance 1 ops(ops/sec): 191647.74
Formal execution: Instance 1 hit(hits/sec): 153318.09
Formal execution: Instance 1 missed(misses/sec): 0.00
Formal execution: Instance 1 latency average (ms): 0.78009
Formal execution: Instance 1 p99 Latency (ms): 1.22
Formal execution: Instance 1 throughput (KB/s): 26929.65
Formal execution: Instance 3 ops(ops/sec): 195943.94
Formal execution: Instance 3 hit(hits/sec): 156755.05
Formal execution: Instance 3 missed(misses/sec): 0.00
Formal execution: Instance 3 latency average (ms): 0.76286
Formal execution: Instance 3 p99 Latency (ms): 1.21
Formal execution: Instance 3 throughput (KB/s): 27533.34
#######################
P99 latency(msec): 1.21
Total Throughput(KB/s): 108793.74
*Total OPS(ops/sec): 774242.26
```

The output contains both `populate` and `Formal execution` stage of each redis instance, we focus on the latter one most of time. Kpi includes:

* ops(ops/sec)
* hit(hits/sec)
* missed(misses/sec)
* latency average (ms)
* throughput (KB/s)
  In the end, a total throughput of all instances is printed as our primary kpi.

### Index Info

- Name: `Redis Memtier`
- Category: `DataServices`

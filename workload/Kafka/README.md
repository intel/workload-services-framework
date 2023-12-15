>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Apache Kafka is a framework implementation of a software bus using stream-processing. It is an open-source software platform developed by the Apache Software Foundation written in Scala and Java. The project aims to provide a unified, high-throughput, low-latency platform for handling real-time data feeds.

The example use case for Kafka is for operational-related tasks such as application logs collection, and event streaming from one system/framework/platform to another.

### Test Case

This workload is measuring Apache Kafka's performance by utilizing the built-in application bundled with Apache Kafka. Currently, the test case measures Apache Kafka producer and consumer performance.

* `run_test.sh` -  Run test
    1. This script collects environment variables and invokes start_test.py to run test cases
* `start_test.py` -  Start test
    1. This script generates a set number of producers and consumers processes according to producer and consumer number.
    2. Each producer process invokes script `kafka-producer-perf-test.sh` which will generate 5 million messages to the Kafka server. (By default, `throughput=-1`, `record-size=1000`, `num-records=5000000`, `compression.type=lz4`, `buffer.memory=33554432`, `batch.size=65536`, `linger.ms=100`)
    3. Each consumer process invokes script `kafka-consumer-perf-test.sh` which will read 10 million messages from Kafka server. (By default, `messages=10000000`, `timeout=600000`)

* kafka_jdk*_gated - Gated test case, for this test case, PARTITIONS, PRODUCERS and CONSUMERS will be set to 1, and cannot be changed.
* kafka_jdk*_1n - Used for single node testing, all pods will be deployed on one K8S worker node.
* kafka_jdk*_3n - Used for multi node (3 nodes) testing, need at least 3 K8S worker nodes for this test case.
* kafka_jdk*_3n_pkm - Used for multi node (3 nodes) testing, need at least 3 K8S worker nodes for this test case.
* support jdk8, jdk11, jdk17 different openjdk versions.

### Quick start
+ How to run.  
  - Step 1: Clone code
  - Step 2: Switch to code root path and run command "mkdir build".
  - Step 3: Go to path *"../script/terraform"* and edit file *terraform-congig.static|aws|gcp|...|.tf* to set your node information.
  - Step 4: Go to path *"../build"* and Run below command to configure the ctest.  
            *"cmake -DPLATFORM=SPR -DBACKEND=terraform -DCUMULUS_SUT=static -DREGISTRY="your_registry_IP:port" -DRELEASE=:latest ..".*  
            According to your test bed, *'DPLATFORM'* can be changed to ICX. *'DCUMULUS_SUT'* can be changed to aws or azure.  
  - Step 5: Switch to path *../build/workload/Kafka* and run *"make"* command.
  - Step 6: Run below command to list all test cases.  
            *"./ctest.sh -N"*  
  - Step 7: Run test case by below command.  
            *"./ctest.sh -R test_static_kafka_jdk17_3n"*  
            *"_1n"* means running on single nodes. *"_3n"* means running on three nodes.

### Customize Test Configurations

Parameters for workload configure:

#### Kafka Settings
| Parameters                           | Default        | Description                                                  |
| ------------------------------------ | -------------- | ------------------------------------------------------------ |
| BROKER_SERVER_NUM                    | 1              | Number of broker server.                                     |
| REPLICATION_FACTOR                   | 1              | Number of backups per partition.                             |
| KAFKA_BENCHMARK_TOPIC                | KAFKABENCHMARK | Kafka topic name.                                            |
| MESSAGES                             | 10000000       | Number of messages to consume.                               |
| NUM_RECORDS                          | 5000000        | Number of records to produce.                                |
| THROUGHPUT                           | -1             | Throughput (records/second) the producer should achieve.     |
| RECORD_SIZE                          | 1000           | Size of each record.                                         |
| COMPRESSION_TYPE                     | lz4            | Compression type                                             |
| CONSUMER_TIMEOUT                     | 600000         | Time the consumer will wait for messages (in milliseconds).  |
| BUFFER_MEM                           | 33554432       | Amount of memory available to the producer for buffering.    |
| BATCH_SIZE                           | 65536          | Producer batch size.                                         |
| LINGER_MS                            | 100            | Time in milliseconds that producer will wait to send batch.  |
| ACKS                                 | 1              | Number of response.                                          |
| FETCH_SIZE                           | 1048576        | Size of bytes fetched per request.                           |
| ENCRYPTION                           | false          | Use SSL for encryption.                                      |
| PAYLOAD_NUM                          | 10000          | Number of random payloads in message.                        |
| NUM_NETWORK_THREADS                  | 0              | Number of threads used to process the network.               |
| SERVER_PROTECTION                    | true           | Limit RECORDS,PRODUCERS based on memory,disk and network.    |
| NUM_REPLICA_FETCHERS                 | 1              | Number of fetcher threads used to replicate records.         |
| REPLICA_FETCH_MAX_BYTES              | 1048576        | Number of bytes of messages to fetch for each partition.     |
| REPLICA_SOCKET_RECEIVE_BUFFER_BYTES  | 65536          | Socket receive buffer for network requests to the leader.    |
| PARTITIONS                           | Number of CPUs | Number of partitions of Kafka Topic.                         |
| PRODUCERS                            | Number of CPUs | Number of Kafka producers.Set to 0 if value is not specified |
| CONSUMERS                            | Number of CPUs | Number of Kafka consumers.Set to 0 if value is not specified |
| SERVER_NUMACTL_OPTIONS               |                | numactl setting  "--physcpubind=0-63%20--localalloc"         |
| CONSUMER_NUMACTL_OPTIONS             |                | numactl setting  "--physcpubind=0-63%20--localalloc"         |
| PRODUCER_NUMACTL_OPTIONS             |                | numactl setting  "--physcpubind=0-63%20--localalloc"         |
| KAFKA_HEAP_OPTS                      |                | Set kafka JVM heap size. "-Xmx4G_-Xms4G"                     |
| ENABLE_MUL_DISK                      | false          | Cloud platform only. Support multiple disks attached.        |
| MOUNT_DISK_COUNT                     |                | Number of disk. MOUNT_DISK_COUNT=CSP_DISK_SPEC_1_DISK_COUNT  |

#### CSP Settings
| Parameters                         | Description                                                          |
| ---------------------------------- | -------------------------------------------------------------------- |
|  'CSP'_CONTROLLER_INSTANCE_TYPE    | Controller instance type                                             |
|  'CSP'_WORKER_INSTANCE_TYPE        | Worker instance type. Worker instance is used for broker             |
|  'CSP'_CLIENT_INSTANCE_TYPE        | Client instance type. Client instance is used for producer/consumer  |
|  'CSP'_ZONE                        |                                                                      |
|  'CSP'_CONTROLLER_OS_DISK_SIZE     | Controller OS disk size                                              |
|  'CSP'_CLIENT_OS_DISK_SIZE         | Client OS disk size                                                  |
|  'CSP'_WORKER_OS_DISK_SIZE         | Worker OS disk size                                                  |
|  'CSP'_CONTROLLER_OS_DISK_TYPE     | Controller OS disk type                                              |
|  'CSP'_CLIENT_OS_DISK_TYPE         | Client OS disk type                                                  |
|  'CSP'_WORKER_OS_DISK_TYPE         | Worker OS disk type                                                  |
|  'CSP'_DISK_SPEC_1_DISK_COUNT      | Number of disks (apart from OS disk) that will be attached to Worker |
|  'CSP'_DISK_SPEC_1_DISK_SIZE       | Disk size that will be attached to Worker                            |
|  'CSP'_DISK_SPEC_1_DISK_TYPE       | Disk type that will be attached to Worker                            |

If multiple disks is required, set `ENABLE_MUL_DISK` to `true`, enable `DISK_SPEC_1` and attach additional disks to workers; Default MOUNT_DIR is `/mnt/disk{N}`, N is the number of disks. **Please keep `MOUNT_DISK_COUNT` the same value as `<CSP>_DISK_SPEC_1_DISK_COUNT` for cloud tests.**

RUN ctest with test config file:
```
All Kafka Settings and CSP Settings can be specified by users through test config file.
And applied by " ./ctest.sh -R testcase_name --config path_to_test_config.yaml -VV " .
Using test config file is helpful for users to reproduce test results and keep track of performance.
Test config is like [test config file](test-config/test-config-aws-bkc.yaml).
```

### Docker Image

The workload contains 3 docker images: `kafka-zookeeper-server`, `producer` and `consumer`. The container interact with each other using Kubernetes Service (ClusterIP). Due to this configuration, it is recommended to run this workload using Kubernetes instead of docker.

* `kafka-zookeeper-server` - Kafka and Zookeeper server container
    * Used to receive messages from producer and send messages to consumer, exposes port `2181`, `9092` and `9093` using `ClusterIP`
* `producer` - Producer container
    * Used to generate and send messages to Kafka and Zookeeper server
* `consumer` - Consumer container
    * Used to get messages from Kafka and Zookeeper server


### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. 

```
./kpi.sh
kafka_p95_latency (ms): *
number_of_producer: *
*Maximum Throughput (MB/s): *
Maximum Throughput for Latency SLA (MB/s): *
max_p95_tx_latency (ms): *
max_p95_latency (ms): *
min_p95_latency (ms): *
avg_p95_latency (ms): *
max_p99_latency (ms): *
min_p99_latency (ms): *
avg_p99_latency (ms): *
```

### Index Info
- Name: `Kafka`
- Category: `DataServices`
- Platform: `SPR`, `ICX`
- Keywords:
- Permission:

### See Also

- [Kafka Configurations](https://kafka.apache.org/documentation/#configuration)

### Introduction

Apache Kafka is a framework implementation of a software bus using stream-processing. It is an open-source software platform developed by the Apache Software Foundation written in Scala and Java. The project aims to provide a unified, high-throughput, low-latency platform for handling real-time data feeds.

The example use case for Kafka is for operational-related tasks such as application logs collection, and event streaming from one system/framework/platform to another.

### Test Case

This workload is measuring Apache Kafka's performance by utilizing the built-in application bundled with Apache Kafka. Currently, the test case measures Apache Kafka producer and consumer performance. 

* `run_test.sh` -  Run test
    1. This script collects environment variables and invokes start_test.py to run test cases
* `start_test.py` -  Start test
    1. This script generates a set number of producers and consumers processes according to variable 'producer_n' and 'consumer_n'.
    2. Each producer process invokes script `kafka-producer-perf-test.sh` which will generate 3 million message to the Kafka server. (`throughput=5000`, `record-size=1000`, `compression.type=lz4`)
    3. Each consumer process invokes script `kafka-consumer-perf-test.sh` which will read 3 million message from Kafka server. (`timeout=500000`)

Run designed test cases:
```
cd build
cmake ..
cd workload/Kafka
ctest -V 
```

Example of test parameters:
```
    REPLICATION_FACTOR: 1
    PARTITIONS: 128
    PRODUCERS: 128
    CONSUMERS: 128
    NUM_RECORDS: 3000000
    THROUGHPUT: 50000
    RECORD_SIZE: 1000
    COMPRESSION_TYPE: lz4
    MESSAGES: 2000000
    KAFKA_BENCHMARK_TOPIC: KAFKABENCHMARK
    CONSUMER_TIMEOUT: 600000
```

### Docker Image

The workload contains 3 docker images: `kafka-zookeeper-server`, `producer` and `consumer`. The container interact with each other using Kubernetes Service (ClusterIP). Due to this configuration, it is recommended to run this workload using Kubernetes instead of docker.

* `kafka-zookeeper-server` - Kafka and Zookeeper server container
    * Used to receive messages from producer and send messages to consumer, exposes port `2181`, `9092` and `9093` using `ClusterIP`
* `producer` - Producer container
    * Used to generate and send messages to Kafka and Zookeeper server
* `consumer` - Consumer container
    * Used to get messages from Kafka and Zookeeper server

```
# Deploy Kafka workload
m4 -I ../../template -DREPLICATION_FACTOR=1 -DPARTITIONS=256 -DKAFKA_BENCHMARK_TOPIC=KAFKABENCHMARK -DMESSAGES=2000000 -DNUM_RECORDS=3000000 -DTHROUGHPUT=5000 -DRECORD_SIZE=1000 -DCOMPRESSION_TYPE=lz4 -DPRODUCERS=256 -DCONSUMERS=256 -DCONSUMER_TIMEOUT=600000 kubernetes-config.yaml.m4 > kubernetes-config.yaml
kubectl apply -f kubernetes-config.yaml

# Retrieve logs
mkdir -p logs-kafka
pod=$(kubectl get pod --selector=job-name=benchmark -o=jsonpath="{.items[0].metadata.name}")
kubectl exec $pod -- cat /export-logs | tar xf - -C logs-kafka

# Delete Kafka workload deployment
kubectl delete -f kubernetes-config.yaml
```

### Test Cases

* kafka_gated - Gated test case, for this test case, PARTITIONS, PRODUCERS and CONSUMERS will be set to 1, and cannot be changed.
* kafka_1n - Used for single node testing, all pods will be deployed on one K8S worker node.
* kafka_3n - Used for multi node (3 nodes) testing, need at least 3 K8S worker nodes for this test case.
* kafka_3n_pkm - Used for multi node (3 nodes) [pkm](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/blob/master/doc/cmakelists.txt.md#special-test-cases) testing, need at least 3 K8S worker nodes for this test case.

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. 

* Due to Primary KPI's measurement methodology, The Primary KPI is expected to increase with the PRODUCERS flag (number of producers)
* To get higher Primary KPI result, please use powerful machine and override PRODUCERS flag.

```
[sfdev@localhost logs-kafka2]$ ./kpi.sh
kafka_p95_latency (ms): x
number_of_producer: xxx
*Maximum Throughput (MB/s): xxxx
Maximum Throughput for Latency SLA (MB/s): x
max_p95_tx_latency (ms): xxxx
```

### Index Info
- Name: `Kafka`
- Category: `DataServices`
- Platform: `ICX`
- Keywords: `Kafka` 
- Permission:

### See Also

- [Kafka Configurations](https://kafka.apache.org/documentation/#configuration)

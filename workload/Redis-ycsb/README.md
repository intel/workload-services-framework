>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Redis is an in-memory data structure store, used as a distributed, in-memory key–value database, cache and message broker, with optional durability. Redis supports different kinds of abstract data structures, such as strings, lists, maps, sets, sorted sets, HyperLogLogs, bitmaps, streams, and spatial indices.
The YCSB is an open-source specification and program suite for evaluating retrieval and maintenance capabilities of computer programs. It is used to get performance of Redis in this workload.

### Test Case

There are only 1 testcase for this workload called `test_redis_default`. There were no overrideable parameter designed for this workload.

Run designed test cases:

```
cd build
cmake -DPLATFORM=ICX ..
cd workload/Redis-ycsb
ctest  
```

### Docker Image

The workload contains three Docker image.

* `redis-ycsb-client` : YCSB benchmark. As a client.
* `redis-ycsb-client` : Redis server. As a server.
* `redis-ycsb-config-center` :  Only used for consistency coordination and synchronization.

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. And a sample output looks like:

```
Throughput redis-ycsb-server-service-6371:6371 (ops/sec): 56176.619291051065
Throughput redis-ycsb-server-service-6371:6371 (ops/sec): 61148.9895129483
*Total Throughput (ops/sec): 117326
Num of Redis Instance: 2
Average Throughput (ops/sec): 58662.8
Standard deviation: 2486.19
```

### Requirements

At least 2 physical nodes in k8s cluster.
To get best performance, please ensure all physical servers configured with high-performance CPU.

### Index Info

- Name: `Redis`
- Category: `DataServices`
- Platform: `EMR`, `SPR`, `ICX`, `GNR`, `SRF` ,`MILAN` , `ROME` , `ARMv8`
- Keywords:

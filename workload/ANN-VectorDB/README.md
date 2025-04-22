>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload runs ANN benchmark without Kubernetes. It deploys selected algorithm directly on bare metal or cloud VM instances.

### Quick start
+ How to run.  
  It is suggested to have no less than 8 CPU cores, 16GB RAM on node.
  - Step 1: Clone code.
  - Step 2: Switch to code root path and run command "mkdir build".
  - Step 3: Go to path *"../script/terraform"* and edit file *terraform-congig.static|aws|gcp|...|.tf* to set your node information.
  - Step 4: Go to path *"../build"* and Run below command to configure the ctest.  
            *"cmake  -DBACKEND=terraform   -DPLATFORM=SPR -DTERRAFORM_SUT=static -DREGISTRY="your registry IP:port" -DRELEASE=":ANN-VectorDB"  -DBENCHMARK="ANN-VectorDB" ..".*
            According to your test bed, *'DPLATFORM'* can be changed to EMR.
  - Step 5: Switch to path *../build/Workload/ANN-VectorDB* and run *"make"* command.
  - Step 6: Run below command to list all test cases.
            *"./ctest.sh -N"*
  - Step 7: Run test case by below command.
            *"./ctest.sh -R test_static_ann-vectordb_\*_pkm"* 
 

### Current Support Machine Instance
+ Bare mental.
  - SPR
  - ICX
  - EMR


### Customize Test Configurations
Refer to [`ctest.md`](../../doc/user-guide/executing-workload/ctest.md#Customize%20Configurations) to customize test parameters.

Parameters for workload configure:
* `ALGORITHM` - The algorithem tested by ANN benchamark. Default value is milvus 
* `DATASET` - The dataset to measure the performance. Default valuse is glove-100-angular.
* `BATCH` - Run all the queries simultaneously. Deault value is False.
* `CPU_LIMIT` - CPU core to run the testcase. Default valuse is 8.
* `MEM_LIMIT` - Memory size to run the testcase. Default value is 16(G).
* `MILVUS_M` - Milvus parameter to run the testcase. Default value is 96.
* `MILVUS_QUERY_ARGS` - Milvus parameter to run the testcase. Default value is 800.


### Test Case

ANN-VectorDB user is used for the test case where it interleaves user provided queries with configurable ratio and distribution.

There are 2 test cases available:
* `test_static_ann-vectordb_*_pkm`
    1. This testcase deploies specific algorithm as the vectorDB, using ANN benchmark to measure the searching performance of this DB. Currently, it supports Milvus and redisearch. And for Post-Si performance analysis. Default trace collection from log "Begin performance testing" and end at "End performance testing".


### Docker Image
As deploying ANN Benchmark directly on bare mental or cloud VM instance, no docker image related.

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the output logs.

```
*Recall Rate: 0.96110
QPS:628.29

avg *Recall Rate: 0.9611
std *Recall Rate: 0
med *Recall Rate: 0.96110
geo *Recall Rate: 0.9611

```

Note:
```
Recall Rate:    Number of true positive predictions to the total number of actual positives in the data.
QPS:	Number of queries received and processed by the VectorDB per second. 

```

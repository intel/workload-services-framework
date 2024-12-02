>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Apache Cassandra is an open source NoSQL distributed database trusted by thousands of companies for scalability and high availability without compromising performance. Linear scalability and proven fault-tolerance on commodity hardware or cloud infrastructure make it the perfect platform for mission-critical data.

This workload is measuring Apache Cassandra performance by using cassandra-stress tool (a Java-based stress testing utility). 

### Quick start
+ How to run.  
  It is better to have no less than 8 CPU cores, 16GB RAM on node. And no less than 4GB for each Cassandra instance.  
  - Step 1: Clone code from https://github.com/intel/workload-services-framework
  - Step 2: Switch to code root path and run command "mkdir build".
  - Step 3: Go to path *"../script/terraform"* and edit file *terraform-congig.static|aws|gcp|...|.tf* to set your node information.
  - Step 4: Go to path *"../build"* and Run below command to configure the ctest.  
            *"cmake  -DBACKEND=terraform   -DPLATFORM=EMR -DTERRAFORM_SUT=static -DREGISTRY="your registry IP:port" -DRELEASE=":Cassandra"  -DBENCHMARK="Cassandra" ..".* 
            According to your test bed, *'DPLATFORM'* can be changed to EMR. *'DCUMULUS_SUT'* can be changed to aws or azure.  
  - Step 5: Switch to path *../build/Workload/Cassandra* and run *"make"* command.
  - Step 6: Run below command to list all test cases.  
            *"./ctest.sh -N"*
  - Step 7: Run test case by below command.  
            *"./ctest.sh -R test_*_cassandra_*n"* 
            *"_1n"* means running on single nodes. *"_2n"* means running on two nodes, server and client separated.
 
+ Run for performance data on EMR bare mental  
  Below steps and configure is for Intel(R) Xeon(R) EMR on bare mental.  
  Pre-requiement for resource:  
  - a). 2 nodes(run test case *"standalone_2n_pkm"*)  
  - b). Enable SCN-2  
  - c). 8 nvme disk mounted to */mnt/disk1/, /mnt/disk2/.../mnt/disk8/ on server node. The nvme disk top performace should be not lower than *INTEL SSDPF21Q016TB*.  
  - d). Disk space required.   
        Each Cassandra instance will generated about 250GB~300GB data on disk. So each mvme disk free space should be no less than 300GB. 


  Steps:  
  
  - Step 2: Switch to code root path and run command "mkdir build".
  - Step 3: Go to path *"../script/terraform"* and edit file *terraform-congig.static.tf* to set your node information.
  - Step 4: Go to path *"../build"* and Run below command to configure the ctest.  
           *"cmake  -DBACKEND=terraform   -DPLATFORM=EMR -DTERRAFORM_SUT=static -DREGISTRY="your registry IP:port" -DRELEASE=":Cassandra"  -DBENCHMARK="Cassandra" ..".*                
  - Step 5: Go to path *"../build/Workload/Cassandra"* and and run *"make"* command.
  - Step 6: Copy ../workload/Cassandra/test-config/bare-mental/test-config-emr.yaml to current directory.                        
  - Step 7: Run below command to list all test cases.
            *"./ctest.sh -N"*  
  - Step 8: Run test case by below command.  
            *"./ctest.sh --testcase test_static_cassandra_standalone_2n_pkm --config=test-config-emr.yaml -V"*


### Current Support Machine Instance
+ Bare mental.
  - EMR, its configure file is test-configure/bare-mental/test-config-erm.yaml
  - SPR, its configure file is test-configure/bare-mental/test-config-spr.yaml
  - ICX, its configure file is test-configure/bare-mental/test-config-icx.yaml

+ cloud.
  - This code can be run on aws, gcp, azure and ali cloud.


### Known issues
Not supprot run Cassandra with Java OpenJdk14 on ARM platform.


### Performance Report
Please refer to PDT report [ `Apache Cassandra Database gen to gen comparison on Ali Cloud` ](https://intel.sharepoint.com/:p:/r/sites/IAGS-DPGPerformanceProgram/_layouts/15/Doc.aspx?sourcedoc=%7BED72816C-1144-43D9-8B53-308277C58501%7D&file=2023Q2042_Apache%20Cassandra%20SPROnAliCloud.pptx&action=edit&mobileredirect=true)


### Customize Test Configurations
Refer to [`ctest.md`](../../doc/user-guide/executing-workload/ctest.md#Customize%20Configurations) to customize test parameters.

Parameters for workload configure:
* `CLIENT_DURATION` - The during time of cassandra client running. In order to warm up, it's better to set this value more than 10 minutes. 
* `CLIENT_THREADS` - Thread number in one client instance to run concurrently.
* `CLIENT_INSERT` - Operation ratio for write. Deault value is 20.
* `CLIENT_SIMPLE` - Operation ratio for read. Default is 80.
* `CLIENT_POP_MAX` - Cassandra DB entries.
* `INSTANCE_NUM` - The nummer of Cassandra server and client instance to run concurrently.
* `CASSANDRA_NUMACTL_VCORES_ENABLE` - For standalone settings. Cassandra server instance will pinned to vcpus(half phsical vcpus, half virtual vcpus). Default is 'false'
* `JVM_HEAP_SIZE` - JVM configure for '-Xms' and '-Xmx'. Here set min (-Xms) and max (-Xmx) heap sizes to the same value to avoid stop-the-world GC pauses during resize. If set value larger than free memory size, it will be adjust to '80% * free memeory size'
* `JDK_VERSION` - Two optios, 'JDK11' and 'JDK14'. JDK11 means use openjdk11. JDK14 means use openjdk14. Default value is 'JDK11'.
* `CASSANDRA_DISK_MOUNT`  - Boolean variable(true|false). Default value is 'false'. If set to 'true', it will use '/mnt/disk[0...INSTANCE_NUM]' for cassandre instance. The purpose is to set each cassandra server instance has its independent disk.
* `CASSANDRA_CONCURENT_READS` - Setting for concurrent_reads in cassandra.yaml
* `CASSANDRA_CONCURENT_WRITES` - Setting for concurrent_writes in cassandra.yaml
* `DEPLOY_MODE` - Cassandra server deploy mode, valie is 'standalone' or 'cluster'. defalut is 'standalone'. If want to run cluster mode, need to set 'export DEPLOY_MODE=cluster'
* `NODE_NUM` - For cluster mode, how many Cassandra server node running in cluster. 
* `REPLICATE_NUM` - For cluster settings. How many replicate number for data in Cassandra database. Default value is 1.


### Test Case

cassandra-stress user is used for the test case where it interleaves user provided queries with configurable ratio and distribution.

There are 4 test cases available:
* `test_*_cassandra_gated`
    1. This testcase is gated.
* `test_*_cassandra_standalone_1n`
    1. This testcase is deploy cassandra as standalone mode, not cluste, runing server and client instance on a single node.
* `test_*_cassandra_Standalone_2n_pkm`
    1. This testcase is deploy cassandra as standalone mode, not cluste. And for Post-Si performance analysis. Default trace collection from log "Begin performance testing" and end at "End performance testing".
* `test_*_cassandra_cluster_pkm`
     1. This testcase is deploy cassandra as cluster mode. And for Post-Si performance analysis. Default trace collection from log "Begin performance testing" and end at "End performance testing".


### Docker Image

The workload contains 4 docker images: `wl-cassandra-server-jdk11`, `wl-cassandra-client-jdk11` `wl-cassandra-server-jdk14`, `wl-cassandra-client-jdk14`. As java Open jdk14 is not a long term supporting version, jdk14 images is only supporting to run on amd64 platform. 

* `wl-cassandra-server-jdk11` - Cassandra server used openjdk11 and cassandra 4.1.0.
* `wl-cassandra-client-jdk11` - Cassandra benchmark used openjdk11 and cassandra 4.1.0.
* `wl-cassandra-server-jdk14` - Cassandra server used openjdk14 and cassandra 4.1.0.
* `wl-cassandra-client-jdk14` - Cassandra benchmark used openjdk14 and cassandra 4.1.0. 


### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the output logs.

```
**test_cassandra_user**
---------------------------------------------
    Partition rate(pk/s) : 193587
    Row rate(row/s)      : 2033872
    Latency mean(ms)     : 1.3
    Latency median(ms)   : 1.1
    Latency 95th percentile(ms)   : 2.3
    Latency 99th percentile(ms)   : 2.3
    Latency 99.9th percentile(ms) : 16.3
    Latency max(ms)      : 229.2
    Total operation time : 00:10:00
---------------------------------------------
*Finally Op rate(op/s): 193587


```

Note:
```
op/s	Number of operations per second performed during the run.
pk/s	Number of partition operations per second performed during the run.
row/s	Number of row operations per second performed during the run.
mean	Average latency in milliseconds for each operation during that run.
med	    Median latency in milliseconds for each operation during that run.
.99	    99% of the time the latency was less than the number displayed in the column.

``` 
### Index Info
- Name: `Cassandra`  
- Category: `DataServices`  
- Platform: `SPR`, `ICX`, `EMR`, `SRF`
- Keywords:   
- Permission:   

- Known Issues:  
  - None  

### See Also
- [Cassandra Official Website](https://cassandra.apache.org/_/index.html)   
- [cassandra-stress user](https://docs.datastax.com/en/dse/6.7/dse-dev/datastax_enterprise/tools/toolsCStressUser.html)

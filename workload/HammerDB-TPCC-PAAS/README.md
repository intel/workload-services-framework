>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is a database workload deployed onto multiple Cloud Service Providers(CSP) to support AWS RDS DB, deployment with one VM instance to run hammerDB application and one AWS Mysql Paas instance or Azure mssql Paas to provide data service.

This deployment is based on one VPC, create three subnets in VPC, VM instance using the one, Paas DB instance using other.

```text

+-----------VPC-----------------------------------------+--------------------------+--------------------------+-------------------------------------

    +--------------------------+                                            +--------------------------+                       +--------------------------+
    |                          |                                            |                          |                       |                          |
    |          Subnet A        |                                            |         Subnet B         |                       |          Subnet C        |
    |                          |                                            |                          |                       |                          |
    |                          |                                            |                          |                       |                          |
    |                          |                                            |                          |                       |                          |
    |                          |                                            |                          |                       |                          |
    |                          |                                            |                          |                       |                          |
    |                          |<-------------------------------------------|--------------------------|---------------------->* endpoint                 |
    |                          |                                            |                          |                       |                          |
    |                          |                                            |                          |                       |                          |
    |        |+---------|      |                                            |                          |                       |                          |
    |        |   VM     |      |                                            |                          |                       |          |+---------|    |
    |        |+---------|      |                                            |                          |                       |          | Paas DB  |    |
    |            ^             |                                            |                          |                       |          |+---------|    |
    |            |             |                                            |                          |                       |                          |
    +---+--------|-------------+                                            +---+----------------------+                       +---+----------------------+
                 |
            |+---|-----|
            |    IGW   |
            |+---|-----|
                 |
                 |
                
                public network

+----------------------------------------------------+--------------------------+--------------------------+--------------------------------------+
```

#### MySQL

There are currently testcases that measure MySQL performance.
* `test_aws_hammerdb_paas_mysql_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement
* `test_aws_hammerdb_paas_mysql_pkm` - PKM Testcase
    1. This testcase is the PKM Testcase.

#### Mssql
There are currently testcases that measure Microsoft SQL Server performance.
* `test_azure_hammerdb_paas_mssql_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement
* `test_azure_hammerdb_paas_mssql_pkm` - PKM Testcase
    1. This testcase is the PKM Testcase.

### Test Case

The workload organizes the following test cases:  
- `gated`: This test case validates the workload feature.
- `pkm`: This test case is with performance analysis.

### Workload Configuration
The workload exposes below variables, which can be configured:
#### HammerDB
- **`TPCC_THREADS_BUILD_SCHEMA`**: Number of threads to build schema. Depends on actual cpu cores.
- **`TPCC_HAMMER_NUM_VIRTUAL_USERS`**: Number of Virtual users, must be less than or equal to number of warehouses and aligned with cpu cores.
- **`TPCC_WAIT_COMPLETE_MILLSECONDS`**:  Wait time after complete in mullseconds.
- **`TPCC_NUM_WAREHOUSES`**: Number of warehouses.
- **`TPCC_MINUTES_OF_RAMPUP`**: Rampup time in minutes before first Transaction Count is taken.
- **`TPCC_MINUTES_OF_DURATION`**: Duration in minutes before second Transaction Count is taken.
- **`TPCC_TOTAL_ITERATIONS`**: Number of transactions before logging off.

#### Mysql
- **`MAX_CONNECTIONS`**: The number of simultaneous client connections allowed.
- **`TABLE_OPEN_CACHE`**: The number of open tables for all threads. Increasing this value increases the number of file descriptors.
- **`TABLE_OPEN_CACHE_INSTANCE`**: The number of open tables cache instances.
- **`BACK_LOG`**: The number of outstanding connection requests MySQL can have.
- **`PERFORMANCE_SCHEMA`**: Enables or disables the Performance Schema.
- **`MAX_PREPARED_STMT_COUNT`**: Used if the potential for denial-of-service attacks based on running the server out of memory by preparing huge numbers of statements.
- **`CHARACTER_SET_SERVER`**: The server's default character set`
- **`COLLATION_SERVER`**: The server's default collation.
- **`TRANSACTION_ISOLATION`**: Sets the default transaction isolation level.
- **`INNODB_FILE_PER_TABLE`**: Use tablespaces or files for Innodb.
- **`INNODB_OPEN_FILES`**: Relevant only if you use multiple tablespaces in innodb. It specifies the maximum number of .ibd files that innodb can keep open at one time
- **`INNODB_BUFFER_POOL_SIZE`**: Automatically scale innodb_buffer_pool_size and innodb_log_file_size based on system memory. Also set innodb_flush_method=O_DIRECT_NO_FSYNC, if supported.
- **`INNODB_FLUSH_LOG_AT_TRX_COMMIT`**: Determines Innodb transaction durability.
- **`JOIN_BUFFER_SIZE`**: Increase the value of join_buffer_size to get a faster full join when adding indexes is not possible.
- **`SORT_BUFFER_SIZE`**: Larger value improves perf for ORDER BY or GROUP BY operations.
- **`INNODB_STATS_PERSISTENT`**: The number of index pages to sample when estimating cardinality and other statistics for an indexed column, such as those calculated by ANALYZE TABLE.
- **`INNODB_SPIN_WAIT_DELAY`**: The maximum delay between polls for a spin lock.
- **`INNODB_MAX_PURGE_LAG_DELAY`**: Specifies the maximum delay in milliseconds for the delay imposed by the innodb_max_purge_lag configuration option
- **`INNODB_MAX_PURGE_LAG`**: Controls how to delay INSERT, UPDATE, and DELETE operations when purge operations are lagging
- **`INNODB_LRU_SCAN_DEPTH`**: A parameter that influences the algorithms and heuristics for the flush operation for the InnoDB buffer pool.
- **`INNODB_PURGE_THREADS`**: The number of background threads devoted to the InnoDB purge operation.
- **`INNODB_ADAPTIVE_HASH_INDEX`**:Whether innodb adaptive hash indexes are enabled or disabled
- **`INNODB_SYNC_SPIN_LOOPS`**: The number of times a thread waits for an innodb mutex to be freed before the thread is suspende`.

#### Mssql
- **`SINGLE_DATABASES_SKU_NAME`**:The single database resource type creates a database in Azure SQL Database with its own set of resources and is managed via a server.Specifies the name of the SKU used by the database. For example, GP_S_Gen5_2,HS_Gen4_1,BC_Gen5_2, ElasticPool, Basic,S0, P2 ,DW100c, DS100
- **`ELASTIC_POOL_ENABLED`**: Enable Elastic pools
- **`ELASTIC_POOL_VCORE_FAMILY`**: The family of hardware generation
- **`ELASTIC_POOL_SKU_TIER`**: The tier of the particular SKU. Possible values are GeneralPurpose, BusinessCritical, if yes, the application will auto select vcore. if not, the application will auto select DTU.
- **`ELASTIC_POOL_SKU_CAPACITY`**: The scale up/out capacity, representing server's compute units.


Follow below steps to run the workload:

#### Mysql
```
# Config CPS(e.g. aws) and build the image
cd build
cmake -DBACKEND=terraform -DTERRAFORM_SUT=aws
make aws
aws configure # please specify a region and output format as json
cd workload/HammerDB-Mysql-PAAS
make
./ctest.sh -N # list test cases

# Run all test cases
./ctest.sh -V

# Run the _pkm test case with customized variables: vpp_worker_cores=1 && nb_tunnels=8  
./ctest.sh --set "INNODB_BUFFER_POOL_SIZE=" -R _pkm -V

# Run the _pkm test case with specific test configure file
TEST_CONFIG=/path/to/aws/test-config-cloud-64vcpus.yaml ./ctest.sh -R _pkm -V
```
#### Mssql
```
# Config CPS(e.g. azure) and build the image
cd build
cmake -DBACKEND=terraform -DTERRAFORM_SUT=azure
make azure
azure configure # please specify a region and output format as json
cd workload/HammerDB-Mysql-PAAS
make
./ctest.sh -N # list test cases

# Run all test cases
./ctest.sh -V

# Run the _pkm test case with customized variables: vpp_worker_cores=1 && nb_tunnels=8  
./ctest.sh --set "INNODB_BUFFER_POOL_SIZE=" -R _pkm -V

# Run the _pkm test case with specific test configure file
# single database vCore module 
TEST_CONFIG=/path/to/test-config/azure/test-config-singleDatabase-vCore-20vcpu.yaml ./ctest.sh -R _pkm -V
# single database DTU module
TEST_CONFIG=/path/to/test-config/azure/test-config-singleDatabase-dtu.yaml ./ctest.sh -R _pkm -V
# elastic pool vCore module
TEST_CONFIG=/path/to/test-config/azure/test-config-elasticpool-vCore.yaml ./ctest.sh -R _pkm -V
# elastic pool dtu module
TEST_CONFIG=/path/to/test-config/azure/test-config-elasticpool-dtu.yaml ./ctest.sh -R _pkm -V
```

### KPI
The following KPI is defined:
- `trans/min`：Transactions Per Minute
- `orders/min`: New Orders Per Minute
Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. 

The expected output will be similar to this. Please note that the numbers might be slightly different.

```
New Orders Per Minute xxx (orders/min): xxxx
Transactions Per Minute xxx (trans/min): xxxx
Peak Num of Virtual Users: xxx
*Peak New Orders Per Minute (orders/min): xxxx
Peak Transactions Per Minute (trans/min): xxxx
```

### Index Info
- Name: `HammerDB-TPCC`  
- Category: `DataServices`  
- Platform: `AWS RDS MYSQL` `Azure mssql`
- Keywords: `PAAS`, `MYSQL`, `Azure` 
- Permission:   


### See Also

- [`HammerDB Official Website`](https://www.hammerdb.com/)
- [`HammerDB Best Practice for PostgreSQL Performance and Scalability`](https://www.hammerdb.com/blog/uncategorized/hammerdb-best-practice-for-postgresql-performance-and-scalability/)
- [`AWS RDS Instance`](https://aws.amazon.com/rds/instance-types/)
- [`Aurora MySQL configuration parameters`](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraMySQL.Reference.html)
- [`Azure Compare vCore and DTU-based`](https://learn.microsoft.com/en-us/azure/azure-sql/database/purchasing-models?view=azuresql)
- [`Azure Elastic pool`](https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-pool-overview?view=azuresql)
- [`Azure single database vCore resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql)
- [`Azure single database DTU resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql)
- [`Azure Elastic pool vCore resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-elastic-pools?view=azuresql)
- [`Azure Elastic pool DTU resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-elastic-pools?view=azuresql)

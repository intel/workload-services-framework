>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is a database workload deployed onto multiple Cloud Service Providers(CSP) to support Azure DB, deployment with one VM instance to run hammerDB application and one Azure flexible Mysql Paas instance.

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
There are currently testcases that measure Microsoft SQL Server performance.
* `test_azure_hammerdb_paas_mysql_flexible_server_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement
* `test_azure_hammerdb_paas_mysql_flexible_server_pkm` - PKM Testcase
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


Follow below steps to run the workload:

#### Mysql
```
# Config CPS(e.g. azure) and build the image
cd build
cmake -DBACKEND=terraform -DTERRAFORM_SUT=azure
make azure
azure configure # please specify a region and output format as json
cd workload/CloudModules-AZURE-RDS-MySQL-Flexible
make
./ctest.sh -N # list test cases

# Run all test cases
./ctest.sh -R test_azure_hammerdb_paas_mysql_flexible_server_pkm -VV

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

### Contact

- Stage1 Contact:
- Validation:
- Stage2 Contact:

### Index Info
- Name: `CloudModules-AZURE-RDS-MySQL-Flexible`  
- Category: `DataServices`  
- Platform: `Azure flexible mysql`
- Keywords: `PAAS`, `MYSQL`, `Azure` 
- Permission:

### See Also
- [`Aurora MySQL configuration parameters`](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraMySQL.Reference.html)
- [`Azure Compare vCore and DTU-based`](https://learn.microsoft.com/en-us/azure/azure-sql/database/purchasing-models?view=azuresql)
- [`Azure Elastic pool`](https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-pool-overview?view=azuresql)
- [`Azure single database vCore resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql)
- [`Azure single database DTU resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql)
- [`Azure Elastic pool vCore resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-elastic-pools?view=azuresql)
- [`Azure Elastic pool DTU resource`](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-elastic-pools?view=azuresql)

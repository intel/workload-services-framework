>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is a database workload deployed onto multiple Cloud Service Providers(CSP) to support Azure DB, deployment with one VM instance to run hammerDB application and one Azure flexible Postgresql flexible server Paas instance.

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

#### Postgresql
There are currently testcases that measure Postgresql flexible Server performance.
* `test_azure_hammerdb_postgresql_flexible_server_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement
* `test_azure_hammerdb_postgresql_flexible_server_pkm` - PKM Testcase
    1. This testcase is the PKM Testcase.

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

#### Postgresql
```
# Config CPS(e.g. azure) and build the image
cd build
cmake -DBACKEND=terraform -DTERRAFORM_SUT=azure
make azure
azure configure # please specify a region and output format as json
cd workload/CloudModules-AZURE-PostgreSQL-Flexible
make
./ctest.sh -N # list test cases

# Run all test cases
./ctest.sh -R test_azure_hammerdb_postgresql_flexible_server_pkm -VV

```

#### Note
To get the best performance data, you need to set the value of the above TPCC_* parameter according to the size of the postgresql flexible server instance, and also need to choose the right instance(default instance is Standard_A2_v2) to run HammerDB.
``` code
./ctest.sh -R test_azure_hammerdb_postgresql_flexible_server_pkm -VV --set TPCC_HAMMER_NUM_VIRTUAL_USERS=xx --set TPCC_NUM_WAREHOUSES=xx --set AZURE_WORKER_INSTANCE_TYPE=Standard_A8_v2
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
- Name: `CloudModules-AZURE-POSTGRESQL-Flexible`  
- Category: `DataServices`  
- Platform: `Azure flexible postgresql`
- Keywords: `PAAS`, `postgresql`, `Azure` 
- Permission:

- Known Issues:  
  - None 

### See Also
- [`terraform-intel-azure-postgresql-flexible-server`](https://github.com/intel/terraform-intel-azure-postgresql-flexible-server)
- [`Azure postgresql flexible server`](hhttps://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview)


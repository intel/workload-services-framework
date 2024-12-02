>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction
Microsoft SQL Server (Structured Query Language) is a proprietary relational database management system developed 
by Microsoft. As a database server, it is a software product with the primary function of storing and retrieving data 
as requested by other software applications—which may run either on the same computer or on another computer across 
a network (including the Internet). Microsoft markets at least a dozen different editions of Microsoft SQL Server, aimed 
at different audiences and for workloads ranging from small single-machine applications to large Internet-facing applications 
with many concurrent users.

HammerDB is the leading benchmarking and load testing software for the worlds most popular databases supporting Oracle Database, SQL Server, IBM Db2, MySQL, MariaDB and PostgreSQL.

### Test Case
Below are the list of testcase(s)
* `test_aws_mssql_windows2019_sql2016` is running mssql 2016 enterprise on windows 2019
* `test_aws_mssql_windows2016_sql2016_pkm` is running mssql 2016 enterprise on windows 2016
* `test_aws_mssql_windows2016_sql2019` is running mssql 2019 enterprise on windows 2016
* `test_aws_mssql_windows2019_sql2019` is running mssql 2019 enterprise on windows 2019

#### 1 Prepare WSF environment
##### 1.1 Download WSF repo
```shell
git clone https://github.com/intel/workload-services-framework.git mywsfrepo
cd mywsfrepo
```

##### 1.2 Setup the development host 
Setup the development host with [setup-dev.sh](../../script/setup/setup-dev.sh). [Document](../../doc/user-guide/preparing-infrastructure/setup-wsf.md#setup-devsh) for this script.
```shell
# in root folder of the repo: mywsfrepo/
cd script/setup
./setup-dev.sh
cd ../.. # back to root folder
```
##### 1.3 Cmake configuration
You can use develop branch for workload evaluation . cmake options that may need your attention:

PLATFORM: SPR, ICX, EMR...check available options under cmake folder
TERRAFORM_SUT: aws.
TERRAFORM_OPTIONS: check available options under terraform options, common used options:
general: --svrinfo
publish: --intel_publish, --owner, --tags
##### 1.3 Initialize Cloud accounts. 
Please follow this [document](../../doc/user-guide/preparing-infrastructure/setup-wsf.md#cloud-setup)
```shell
# in build folder of the repo: mywsfrepo/build
make aws           # or make -C ../.. aws, if under build/workload/<workload>
$ aws configure    # please specify a region and output format as json
$ exit
```

For now, you can continue to evaluate the workload.
#### 2 Evaluate the workload
##### 2.1 List available test cases with `ctest.sh`
```shell
# in build folder of the repo: mywsfrepo/build
./ctest.sh -N
# part of output:
#   Test #1: test_aws_mssql_windows2019_sql2016
#   Test #2: test_aws_mssql_windows2016_sql2019
#   Test #3: test_aws_mssql_windows2016_sql2016_pkm
#   Test #4: test_aws_mssql_windows2016_sql2016_gated
#   Test #5: test_aws_mssql_windows2019_sql2019

```
Simply run a testcase:
```shell
./ctest.sh -R  test_aws_mssql_windows2019_sql2016_pkm -VV --set AWS_DISK_SPEC_1_DISK_COUNT=2 --set AWS_WORKER_OS_TYPE=windows2016 --set AWS_CLIENT_OS_TYPE=windows2016 --set MAX_SER=29490 --set AWS_WORKER_INSTANCE_TYPE=m6i.2xlarge --set AWS_CLIENT_INSTANCE_TYPE=m6i.2xlarge
```

Full test process with VU scaling and multiple runs, the VU scaling list is based on vcpus:
```shell
# first VU scaling, the VU scaling list is based on vcpus. Use 8vcpus setting here
./ctest.sh -R test_aws_mssql_windows2019_sql2016_pkm -VV --loop=1 --config=<path> --set TPCC_HAMMER_NUM_VIRTUAL_USERS="48_56_64_72_80"
# second performance test, suppose VU 16 is optimal in scaling test. --loop=3 or --burst=3 are both fine.
./ctest.sh -R test_aws_mssql_windows2019_sql2016_pkm -VV --loop=3 --config=<path> --set TPCC_HAMMER_NUM_VIRTUAL_USERS="64"
```

### KPI
Run the [`list-kpi.sh`](../../doc/user-guide/collecting-results/list-kpi.md) script to parse the KPIs from the validation logs. 

The expected output will be similar to this. Please note that the numbers might be slightly different. 

```
# status: passed
New Orders Per Minute VU2 (orders/min): 82130
Transactions Per Minute VU2 (trans/min): 188754
Peak Num of Virtual Users: 2
*Peak New Orders Per Minute (orders/min): 82130
Peak Transactions Per Minute (trans/min): 188754

avg *Peak New Orders Per Minute (orders/min): 82130
std *Peak New Orders Per Minute (orders/min): 0
med *Peak New Orders Per Minute (orders/min): 82130
geo *Peak New Orders Per Minute (orders/min): 82130

```

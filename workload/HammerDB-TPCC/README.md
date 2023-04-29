### Introduction

HammerDB is the leading benchmarking and load testing software for the worlds most popular databases supporting Oracle Database, SQL Server, IBM Db2, MySQL, MariaDB and PostgreSQL.

This workload uses HammerDB to measure Database(s) performance. At this moment, this benchmarks measure performance of these databases :

* MySQL


### Test Case
Below are the list of testcase(s) for specific database(s).

#### MySQL

There are currently testcases that measure MySQL performance.

* `test_static_hammerdb_tpcc_mysql_disk_hugepage_off_pkm` - Default Testcase
    1. This testcase is the default testcase.
* `test_static_hammerdb_tpcc_mysql_disk_hugepage_on_pkm` - Default Testcase
    1. This testcase is the default testcase.
* `test_static_hammerdb_tpcc_mysql_disk_hugepage_on_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement
* `test_static_hammerdb_tpcc_mysql_disk_hugepage_off_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement
* `test_static_hammerdb_tpcc_mysql_ramfs_hugepage_on_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement with ramfs
* `test_static_hammerdb_tpcc_mysql_ramfs_hugepage_off_gated` - Gated Testcase
    1. This testcase is the default testcase with less demanding requirement with ramfs
* `test_static_hammerdb_tpcc_mysql_ramfs_hugepage_on_pkm` - Default Testcase + RAMFS
    1. This testcase is the default testcase with RAMFS as storage for mysql.
    2. Database is storage intensive. Although not practical, using RAM as storage will reduce the bottleneck introduced by storage.
* `test_static_hammerdb_tpcc_mysql_ramfs_hugepage_off_pkm` - Default Testcase + RAMFS
    1. This testcase is the default testcase with RAMFS as storage for mysql.
    2. Database is storage intensive. Although not practical, using RAM as storage will reduce the bottleneck introduced by storage.

### Docker Image

Below are the list of Docker images for specific database(s). Due to the interaction between these containers, it is expected to run this workload using Kubernetes instead of Docker.

Please make sure to read the section below for specific configuration to run those testcases.

Remark: `validate.sh` are used to prepare the testcase flags. This is due to high number of configurable flags.


Thanks to the flexibility of the framework, we have both manual and automated way to deploy/run this workload. We also have a way to configure host with pre-defined file (kernel boot param & ulimit)

### Manual Deployment

```
# Deploy workload using generated testcase flags
docker run --rm -v ${PWD}/helm:/apps:ro alpine/helm:3.7.1 template /apps --set DB_TYPE=mysql --set FS_TYPE=disk --set HUGEPAGE_STATUS=off > kubernetes-config.yaml
kubectl apply -f kubernetes-config.yaml

# Run the workload and retrieve logs
mkdir -p logs-<REPLACE_YOUR_TESTCASE_HERE>
pod=$(kubectl get pod --selector=job-name=benchmark -o=jsonpath="{.items[0].metadata.name}")
kubectl exec $pod -- cat /export-logs | tar xf - -C logs-<REPLACE_YOUR_TESTCASE_HERE>

# Delete workload deployment
kubectl delete -f kubernetes-config.yaml
```


#### MySQL
The docker image for this workload is:
* `tpcc-hammerdb` - Docker image to run benchmark.
    * `entrypoint.sh` will run specific configuration depending on the testcase
* `tpcc-mysql` - Prebuilt image from official mysql (`mysql:8.0.26`)
    * required for all testcase:
        * kubernetes node with `HAS-SETUP-HUGEPAGE-2048kB-<your_hugepage_size>` label
        * See also: [Hugepage Setup](../../doc/setup-hugepage.md)

This workload should be executed on Kubernetes with specific label (nodeSelector).
Use this command to enable those capability & label:

#### Setting up Hugepages
```
# configure 32GB hugepages by default
sudo grubby --update-kernel=DEFAULT --args="hugepages=16384"

# configure kubernetes with HAS-SETUP-HUGEPAGE-2048kB-16384 label
kubectl label nodes <your_node_name> HAS-SETUP-HUGEPAGE-2048kB-16384="yes"

# reboot is REQUIRED

# once testcase is completed, you can remove hugepages configuration & the label
sudo grubby --update-kernel=DEFAULT --remove-args="hugepages=16384"
kubectl label nodes <your_node_name> HAS-SETUP-HUGEPAGE-2048kB-16384-

# The hugepage size depends on buffer pool size of database, by default the ratio is 0.5, for example:

Database    Buffer pool size    Hugepage size         Hugepages                      Label               
mysql               96GB                128GB           65536             HAS-SETUP-HUGEPAGE-2048kB-32768

```

#### Mount host disk(NVME SSD recommended) as database container storage
By default, the host mount directory enabled with mount point `/mnt/disk1`
Pretty much recommand to configure 4K aligment for NVME disk if supported

#### check nvme disk if 4K aligned supported
sudo nvme id-ns /dev/nvme0n1 -H |grep 4096 # possible output as follows:
...
LBA Format  1 : Metadata Size: 0   bytes - Data Size: 4096 bytes - Relative Performance: 0 Best (in use)
...

#### format to 4K
sudo nvme format /dev/nvme0n1 -l <LBA> # here LBA is above value number 1, diff output with diff value

#### run test case with 4K alignment
export MYSQL_INNODB_PAGE_SIZE=4K && ctest -R <testcase>

#### For disk 4K alignment refer to [Intel SSDs perform better with a 4096 Byte (4KB) alignment](https://www.intel.com/content/dam/www/public/us/en/documents/white-papers/ssd-server-storage-applications-paper.pdf )

```
# create label on mounted node
kubectl label nodes <node_name> HAS-SETUP-DISK-MOUNT-1="yes"

```

### RUN on multi-node
By default, the workload runs on multi-node
```
# Nice to have to disable irqbalance service on Bara Metal host machine
systemctl disable irqbalance.service

# The container will auto bind network interrupts on affnity cpu cores by sequence
export ENABLE_IRQ_AFFINITY=true # by default the value is true

ctest -R <testcase>

```

### KPI
Run the [`list-kpi.sh`](../../doc/ctest.md#list-kpish) script to parse the KPIs from the validation logs. 

The expected output will be similar to this. Please note that the numbers might be slightly different. 
Primary KPI is `Peak New Orders Per Minute (orders/min)` which has a * as prefix

```
New Orders Per Minute xxx (orders/min): xxxxx
Transactions Per Minute xxx (trans/min): xxxxx
Peak Num of Virtual Users: xxx
*Peak New Orders Per Minute (orders/min): xxxxx
Peak Transactions Per Minute (trans/min): xxxxx
```

### Index Info
- Name: `HammerDB-TPCC`  
- Category: `DataServices`  
- Platform: `ICX`  
- Keywords: `MYSQL`  
- Permission:   

### See Also

- [`HammerDB Official Website`](https://www.hammerdb.com/)



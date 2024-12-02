>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload uses HammerDB to measure PostgreSQL performance. The workload supports multiple postgres instances with `numactl` management. By default, each HammerDB or postgres instance is bound to 4 physical cores (can be changed with `SERVER_CORES_PI` and `CLIENT_CORES_PI`). Users need to calculate the number of instance according to the number of cores on SUT. By default, there is only one instance. 

There are two scenarios provided:

- Single node: **only supports 2 socket SUTs.** Server instances are bound to socket 0 and client instances are bound to socket 1. Users must use `-DTERRAFORM_OPTIONS="--compose"` in cmake or specify `--options="--compose"` in ctest.
- 2 nodes: supports either 1 socket or 2 socket SUTs. Users must use `-DTERRAFORM_OPTIONS="--docker"` in cmake or specify `--options="--docker"` in ctest. And also specify `--set RUN_SINGLE_NODE=false` in ctest. if not, the workload will use default single-node settings and fails.

### Testcases

The HammerDB-PGSQL workload organizes the following test cases:  

* `hammerdb-pgsql_hugepage_on`: This test case runs with hugepage on.
* `hammerdb-pgsql_hugepage_off`: This test case runs with hugepage off.
* `hammerdb-pgsql_hugepage_off_pkm` - This test case runs with hugepage off.

* `hammerdb-pgsql_hugepage_gated` - This test case runs with minimized demands & time.

### Configurations

The HammerDB-PGSQL workload can be configured with the following parameters:  

- **`DB_INSTANCE`**: Specify the number of postgres/HammerDB instances to be deployed.
- **`RUN_SINGLE_NODE`**: `true` by default. If `true`, both postgres/HammerDB instances will be deploy on same node; if `false`, postgres/HammerDB instances will be deploy on 2 different nodes.
- **`CLIENT_CORES_PI`**: Refer to cores used by per client instance. By default it's 4.
- **`SERVER_CORES_PI`**: Refer to cores used by per server instance. By default it's 4.
- **`CLIENT_SOCKET_BIND_NODE`**: If use `0`, client instance starts binding from socket 0; If use `1`, client instance starts binding from socket 1;  **Only valid in 2 nodes scenario**.
- **`SERVER_SOCKET_BIND_NODE`**: If use `0`, server instance starts binding from socket 0; If use `1`, server instance starts binding from socket 1;  **Only valid in 2 nodes scenario**.
- **`ENABLE_MOUNT_DIR`**: Specify whether to enable volume mount or not. If `true`, data dir of postgres will be mounted to the `/mnt/disk{n}` dir on host machine.
- **`MULTI_DISK_NUM`**: Specify the number of local disks to be mounted with.
- **`TPCC_NUM_WAREHOUSES`**: Specify the number of warehouses to be created.
- **`TPCC_MINUTES_OF_RAMPUP`**: Specify the number of minutes to ramp up before test.
- **`TPCC_MINUTES_OF_DURATION`**: Specify the number of minutes to test.
- **`TPCC_VU_NUMBER`**: Specify the number of virtual users.
- **`TPCC_VU_THREADS`**: Specify the number of threads of a virtual user.

### Evaluation

Run workload testcase as follows:

* single node

```
# Run the _hugepage_off test case with DB_INSTANCE=2, will need 4*2*2=16 vcpus.
./ctest.sh -R _hugepage_off$ --set DB_INSTANCE=2 --options="--compose" -V
```

* 2 nodes

```
./ctest.sh -R _hugepage_off$ --set RUN_SINGLE_NODE=false --options="--docker" -V
```

### Test Config Example

*  [test-config-1socket-2nodes.yaml](test-config/test-config-1socket-2nodes.yaml) an example to specify test socket in 2 node scenario.

```
./ctest.sh -R _hugepage_off$ --config path_to/test-config-1socket-2node.yaml --options="--docker" -V
```

### KPI

The following KPI is defined:

- `Total NOPM`: New orders per minute in total.
- `Average NOPM`: New orders per minute in average.

```
./list-kpi.sh logs*
```

### Performance BKM

The HammerDB-PGSQL workload can run on single node with `docker-compose` and 2 nodes with `docker`. A two-socket system is required for single node.

### Index Info

- Name: `HammerDB-PGSQL`
- Category: `DataServices`
- Platform: `GNR`, `SRF`, `SPR`, `ICX`, `EMR`
- keywords: `POSTGRES`, `HammerDB`
- Permission:

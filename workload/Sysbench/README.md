>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Sysbench is an open-source and multi-purpose benchmark utility that evaluates the parameter features tests for CPU, memory, I/O, and database (MySQL) performance. This tool is important to benchmark the MySQL parameters especially when running a load of the intensive database. It is a freely available command-line tool that provides an uncomplicated and direct way to test your Linux system.

### Test Case

The Sysbench workload provides test cases evaluate CPU, memory, and database (MySQL) performance.

Use the following commands to show the list of test cases:
```
cd build
cmake ..
cd workload/Sysbench
./ctest.sh -N
```
Test cases:
```
Test #1: test_sysbench_pkm
Test #2: test_sysbench_gated
Test #3: test_sysbench_cpu
Test #4: test_sysbench_memory
Test #5: test_sysbench_mysql
Test #6: test_sysbench_mutex
```
### Tunables

This workload provides several tests  cases with the following configuration parameters for mysql testcase

- **BUFFER_POOL_SIZE**: Specify the BUFFER_POOL_SIZE: based on Vcpus .default is 4.

### Docker Image
The workload provides a single docker image: `sysbench`. Run the workload as follows:

```
mkdir -p logs
id=$(docker run --rm --detach -e MODE=cpu -e THREADS=1 -e TIME=10 -e CPU_MAX_PRIME=5000 easyrec)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

### KPI

Run the [kpi.sh](kpi.sh) script to parse the KPIs from the validation logs.

KPI output example:
```
*The CPU average latency time (ms): 0.28
Built target kpi_sysbench_sysbench_gated
```


### Index Info
- Name: `sysbench`
- Category: `Synthetic`
- Platform: `SPR`, `ICX`, `EMR`, `SRF`, `GNR`



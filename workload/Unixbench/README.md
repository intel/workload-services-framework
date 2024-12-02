>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

UnixBench is the original BYTE UNIX benchmark suite, updated and revised by many people over the years.

The purpose of UnixBench is to provide a basic indicator of the performance of a Unix-like system; hence, multiple tests are used to test various aspects of the system's performance. These test results are then compared to the scores from a baseline system to produce an index value, which is generally easier to handle than the raw scores. The entire set of index values is then combined to make an overall index for the system.

You can refer to https://github.com/kdlucas/byte-unixbench for details

### Steps to build the workload

  **`mkdir build`** <br>
  **`cd build`** <br>
  **`cmake -DPLATFORM= -DREGISTRY= -DREGISTRY_AUTH= -DRELEASE=:latest -DTIMEOUT=54000,5600 -DBENCHMARK=Unixbench -DBACKEND=terraform -DTERRAFORM_OPTIONS='--docker --sar --collectd --svrinfo --intel_publish --owner=test --msrinfo --tags=unixbench_test' -DTERRAFORM_SUT='static' -DSPOT_INSTANCE=false ..`** <br>
  **`make`** <br>
- (cmake command mentioned above can be used as a reference to run Unixbench workload and can be changed according to user requirements.) <br>
(Doing make will build container images for unixbench)

### Test Case

UnixBench contains multiple test cases and you can run one case alone. Or run allinone test case to run all deflaut test case.
Use the following commands to show the list of test cases:
```
cd build
cmake ..
cd workload/Unixbench
./ctest.sh -N
./ctest.sh -R test_static_unixbench_allinone_benchmark
```
Test cases:
```
  Test  #1: test_static_unixbench_allinone_pkm
  Test  #2: test_static_unixbench_allinone_gated
  Test  #3: test_static_unixbench_dhry2reg_benchmark
  Test  #4: test_static_unixbench_whetstone-double_benchmark
  Test  #5: test_static_unixbench_fsbuffer_benchmark
  Test  #6: test_static_unixbench_fstime_benchmark
  Test  #7: test_static_unixbench_fsdisk_benchmark
  Test  #8: test_static_unixbench_pipe_benchmark
  Test  #9: test_static_unixbench_context1_benchmark
  Test #10: test_static_unixbench_spawn_benchmark
  Test #11: test_static_unixbench_execl_benchmark
  Test #12: test_static_unixbench_shell1_benchmark
  Test #13: test_static_unixbench_shell8_benchmark
  Test #14: test_static_unixbench_syscall_benchmark
  Test #15: test_static_unixbench_allinone_benchmark
```
### Docker Image
The workload provides a single docker image: `unixbench`. Run the workload as follows:

```
mkdir -p logs
id=$(docker run --rm --detach unixbench:latest)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```
### Customize Test Configurations
Refer to [`ctest.md`](../../doc/user-guide/executing-workload/ctest.md#Customize%20Configurations) to customize test parameters.

| Parameters                           | Default        | Description                                                  |
| ------------------------------------ | -------------- | ------------------------------------------------------------ |
| ITERATION_COUNT                      | 10             | Run <count> iterations for each test                         |
| PARALLEL_COUNT                       | 1              | Run <n> copies of each test in parallel                      |
| NUMACTL_OPTIONS                      | ""             | --physcpubind=0-223%20--localalloc;                          |
| NUMA_ENABLE                          | false          |  --set NUMA_ENABLE=true when you are running on cloud        |


### KPI

Run the [kpi.sh](kpi.sh) script to parse the KPIs from the validation logs.

KPI output example:
```
System Benchmarks Index Values         INDEX
Dhrystone_2_using_register_variables:  4918.0
*System_Benchmarks_Index_Score:        4918.0
```
### CLOUD BKM

To run this benchmark on cloud set NUMA_ENABLE to true in ctest options.



### Index Info
- Name: `unixbench`
- Category: `Synthetic`
- Platform: `SPR`, `ICX`, `EMR`, `SRF`, `GNR`



